import 'dart:async';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:get/get.dart';

class InboxController extends GetxController {
  final ChatRepository repo;

  InboxController({required this.repo});

  final Brain brain = Get.find<Brain>();

  final Rx<String?> currentUserId = Rx<String?>(null);
  final Rx<String?> companyId = Rx<String?>(null);

  final conversations = Rxn<List<Conversation>>();
  final isLoading = true.obs;
  final error = RxnString();

  /// userId → nombre para mostrar
  final RxMap<String, String> userNames = <String, String>{}.obs;

  StreamSubscription<List<Conversation>>? _inboxSub;

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();

    currentUserId.value =
        brain.company.value?.id ?? brain.employee.value!.uid;
    companyId.value =
        brain.company.value?.id ?? brain.employee.value!.companyId;

    _buildNamesFromBrain();
    _listen();
    _bootstrap();
  }

  @override
  void onClose() {
    _inboxSub?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────
  // Resolución de nombres
  // ─────────────────────────────────────────────

  void _buildNamesFromBrain() {
    // Empresa/farmacia
    final company = brain.company.value;
    if (company != null) {
      userNames[company.id] = company.legalName;
    } else {
      // Usuario empleado: usamos fallback hasta que cargue de Firestore
      userNames[companyId.value!] = 'Farmacia';
    }

    // Empleado actual
    final emp = brain.employee.value;
    if (emp != null) userNames[emp.uid] = emp.name;

    // Lista de empleados ya cargada en Brain
    _syncFromBrainEmployees();

    // Reacciona a cambios futuros
    ever(brain.companyEmployees, (_) => _syncFromBrainEmployees());
  }

  void _syncFromBrainEmployees() {
    for (final e in brain.companyEmployees) {
      userNames[e.uid] = e.name;
    }
  }

  String nameForUser(String userId) => userNames[userId] ?? userId;

  // ─────────────────────────────────────────────
  // Inicialización asíncrona: nombres + grupo
  // ─────────────────────────────────────────────

  Future<void> _bootstrap() async {
    try {
      // 1. Obtener nombres de todos los miembros desde Firestore
      final names = await repo.getMemberNames(companyId.value!);
      userNames.addAll(names);

      // 2. Asegurar que existe el chat grupal con todos los miembros
      await _ensureGroupChat();
    } catch (_) {
      // No crítico: el chat sigue funcionando sin esto
    }
  }

  Future<void> _ensureGroupChat() async {
    final cId = companyId.value!;
    final me = currentUserId.value!;

    // Miembros: farmacia + todos los empleados conocidos + yo mismo
    final allIds = <String>{cId, me};
    for (final e in brain.companyEmployees) {
      allIds.add(e.uid);
    }
    // También incluir los ids que tengamos en userNames (por si vinieron de Firestore)
    allIds.addAll(userNames.keys);

    await repo.ensureDefaultGroup(
      companyId: cId,
      pharmacyUserId: cId,
      allMemberIds: allIds.toList(),
    );
  }

  // ─────────────────────────────────────────────
  // Stream inbox
  // ─────────────────────────────────────────────

  void _listen() {
    isLoading.value = true;
    try {
    _inboxSub = repo
        .streamInbox(currentUserId.value!, companyId.value!)
        .listen(
          (list) {
            conversations.value = list;
            isLoading.value = false;
          },
          onError: (e) {
            error.value = e.toString();
            print('Error escuchando inbox: $e');
            isLoading.value = false;
          },
        );
    } catch (e) {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  // Abrir / crear conversaciones
  // ─────────────────────────────────────────────

  /// Abre (o crea) un chat 1:1 con [otherUserId].
  Future<void> openDirectConversation(String otherUserId) async {
    try {
      final conv = await repo.ensureDirectConversation(
        companyId: companyId.value!,
        userA: currentUserId.value!,
        userB: otherUserId,
      );
      Get.toNamed(
        Routes.chat,
        arguments: {
          'conversation': conv,
          'currentUserId': currentUserId.value,
          'displayName': nameForUser(otherUserId),
        },
      );
    } catch (_) {}
  }

  /// Abre una conversación existente (grupo o DM).
  void openConversation(Conversation c) {
    final displayName = c.isGroup
        ? c.title
        : dmTitle(c);

    Get.toNamed(
      Routes.chat,
      arguments: {
        'conversation': c,
        'currentUserId': currentUserId.value,
        'displayName': displayName,
      },
    );
  }

  String dmTitle(Conversation c) {
    if (c.title.isNotEmpty) return c.title;
    if (c.memberIds.length == 2) {
      final me = currentUserId.value ?? '';
      final otherId =
          c.memberIds.first == me ? c.memberIds.last : c.memberIds.first;
      return nameForUser(otherId);
    }
    return 'Chat';
  }

  // ─────────────────────────────────────────────
  // Lista de contactos para nuevo DM
  // ─────────────────────────────────────────────

  /// Todos los usuarios con los que el usuario actual puede iniciar un DM.
  List<({String id, String name})> get contactList {
    final me = currentUserId.value ?? '';
    final cId = companyId.value ?? '';
    final contacts = <({String id, String name})>[];

    // Farmacia (si no soy la farmacia)
    if (me != cId) {
      contacts.add((id: cId, name: userNames[cId] ?? 'Farmacia'));
    }

    // Empleados (excepto yo mismo)
    for (final e in brain.companyEmployees) {
      if (e.uid != me) {
        contacts.add((id: e.uid, name: e.name));
      }
    }

    // Si no hay empleados en Brain pero tenemos nombres de Firestore
    if (brain.companyEmployees.isEmpty) {
      for (final entry in userNames.entries) {
        if (entry.key != me && entry.key != cId) {
          // Evitar duplicados
          if (!contacts.any((c) => c.id == entry.key)) {
            contacts.add((id: entry.key, name: entry.value));
          }
        }
      }
    }

    return contacts;
  }
}
