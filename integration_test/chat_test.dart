// Chat interno contra el emulador: grupo "Todos", envío real de mensajes
// (reglas de Firestore incluidas), lectura por el otro rol y chat directo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/qa_harness.dart';

const _msgCompany = 'Hola equipo, mensaje QA de la farmacia';
const _msgEmployee = 'Recibido, responde Ana (QA)';

Future<void> _logoutEmployee(WidgetTester tester) async {
  await tapText(tester, 'Perfil');
  await waitFor(tester, find.text('Mi cuenta'));
  await tapText(tester, 'Cerrar sesión');
  await waitFor(tester, find.text('¿Seguro que quieres cerrar sesión?'));
  await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión').last);
  await waitFor(tester, find.text('ACCESO PARA FARMACIAS'), timeout: const Duration(seconds: 20));
}

Future<void> _logoutCompany(WidgetTester tester) async {
  await tapText(tester, 'Perfil');
  await tapText(tester, 'Cerrar sesión');
  await waitFor(tester, find.text('ACCESO PARA FARMACIAS'), timeout: const Duration(seconds: 20));
}

Future<void> _sendMessage(WidgetTester tester, String text) async {
  await typeInto(tester, 'Escribe un mensaje…', text);
  await tester.tap(find.byIcon(Icons.send_rounded));
  await waitFor(tester, find.text(text), timeout: const Duration(seconds: 20));
}

Future<List<Map<String, dynamic>>> _groupConversations() async {
  final docs = await emulatorRunQuery({
    'from': [{'collectionId': 'conversations'}],
    'where': {'compositeFilter': {'op': 'AND', 'filters': [
      {'fieldFilter': {'field': {'fieldPath': 'companyId'}, 'op': 'EQUAL', 'value': {'stringValue': 'qa-company-paid'}}},
      {'fieldFilter': {'field': {'fieldPath': 'isGroup'}, 'op': 'EQUAL', 'value': {'booleanValue': true}}},
    ]}},
  });
  return docs;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CHAT', () {
    testWidgets('CHAT-001 la farmacia ve el grupo "Todos" con todos los miembros', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await tapText(tester, 'Chat');
      await waitFor(tester, find.text('Chat interno'));
      await waitFor(tester, find.text('Todos'), timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));
      final groups = await _groupConversations();
      expect(groups.length, 1, reason: 'exactamente un grupo "Todos" por empresa (sin duplicados)');
      final members = (restFields(groups.single)['memberIds'] as List).cast<String>();
      expect(members, contains('qa-company-paid'));
      expect(members, contains('qa-emp-ana'));
      expect(members, contains('qa-emp-luis'));
      expect(members, isNot(contains('qa-emp-borrado')), reason: 'los empleados eliminados no entran en el grupo');
      expect(tester.takeException(), isNull);
    });

    testWidgets('CHAT-002 enviar mensaje al grupo: aparece en pantalla y se persiste con senderId correcto', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Todos');
      await waitFor(tester, find.widgetWithText(TextField, 'Escribe un mensaje…'), timeout: const Duration(seconds: 20));
      // Botón de enviar deshabilitado sin texto: no crea mensajes.
      await tester.tap(find.byIcon(Icons.send_rounded), warnIfMissed: false);
      await pumpFor(tester, const Duration(seconds: 1));
      final group = (await _groupConversations()).single;
      final convId = (group['name'] as String).split('/').last;
      expect(await emulatorListDocs('conversations/$convId/messages'), isEmpty);

      await _sendMessage(tester, _msgCompany);
      await pumpFor(tester, const Duration(seconds: 2));
      final msgs = (await emulatorListDocs('conversations/$convId/messages')).map(restFields).toList();
      expect(msgs.length, 1);
      expect(msgs.single['senderId'], 'qa-company-paid');
      expect(msgs.single['text'], _msgCompany);
      final conv = restFields((await emulatorGetDoc('conversations/$convId'))!);
      expect(conv['lastMessageText'], _msgCompany);
      final unread = (conv['unreadCounts'] ?? {}) as Map;
      expect(unread['qa-emp-ana'], 1, reason: 'el destinatario acumula 1 no leído');
      expect(unread['qa-company-paid'] ?? 0, 0, reason: 'el remitente no se cuenta a sí mismo');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await waitFor(tester, find.text('Chat interno'));
      await tapText(tester, 'Inicio');
      await _logoutCompany(tester);
    });

    testWidgets('CHAT-003 el empleado ve el mensaje, el no leído se limpia al abrir y puede responder', (tester) async {
      await launchApp(tester);
      await loginAsEmployee(tester, email: Seed.empAnaEmail);
      await waitFor(tester, find.text('¡Hola, Ana!'), timeout: const Duration(seconds: 40));
      await tapText(tester, 'Chat');
      await waitFor(tester, find.text('Chat interno'));
      await waitFor(tester, find.text('Todos'), timeout: const Duration(seconds: 20));
      await waitFor(tester, find.textContaining('mensaje QA de la farmacia'), timeout: const Duration(seconds: 20));
      await tapText(tester, 'Todos');
      await waitFor(tester, find.text(_msgCompany), timeout: const Duration(seconds: 20));
      await pumpFor(tester, const Duration(seconds: 2));
      final group = (await _groupConversations()).single;
      final convId = (group['name'] as String).split('/').last;
      var conv = restFields((await emulatorGetDoc('conversations/$convId'))!);
      expect(((conv['unreadCounts'] ?? {}) as Map)['qa-emp-ana'] ?? 0, 0, reason: 'abrir el chat marca como leído');

      await _sendMessage(tester, _msgEmployee);
      await pumpFor(tester, const Duration(seconds: 2));
      final msgs = (await emulatorListDocs('conversations/$convId/messages')).map(restFields).toList();
      expect(msgs.length, 2);
      expect(msgs.where((m) => m['senderId'] == 'qa-emp-ana').length, 1);
      conv = restFields((await emulatorGetDoc('conversations/$convId'))!);
      expect(((conv['unreadCounts'] ?? {}) as Map)['qa-company-paid'], 1);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await waitFor(tester, find.text('Chat interno'));
    });

    testWidgets('CHAT-004 chat directo empleado → farmacia: se crea una sola conversación 1:1', (tester) async {
      await launchApp(tester);
      await waitFor(tester, find.text('Chat interno'));
      await tester.tap(find.byType(FloatingActionButton));
      await pumpFor(tester, const Duration(milliseconds: 800));
      await tapText(tester, Seed.companyPaidName);
      await waitFor(tester, find.widgetWithText(TextField, 'Escribe un mensaje…'), timeout: const Duration(seconds: 20));
      await _sendMessage(tester, 'Mensaje directo QA');
      await pumpFor(tester, const Duration(seconds: 2));
      final dms = await emulatorRunQuery({
        'from': [{'collectionId': 'conversations'}],
        'where': {'compositeFilter': {'op': 'AND', 'filters': [
          {'fieldFilter': {'field': {'fieldPath': 'companyId'}, 'op': 'EQUAL', 'value': {'stringValue': 'qa-company-paid'}}},
          {'fieldFilter': {'field': {'fieldPath': 'isGroup'}, 'op': 'EQUAL', 'value': {'booleanValue': false}}},
        ]}},
      });
      final mine = dms.map(restFields).where((c) => (c['memberIds'] as List).contains('qa-emp-ana')).toList();
      expect(mine.length, 1, reason: 'una única conversación directa Ana↔farmacia');
      expect((mine.single['memberIds'] as List).toSet(), {'qa-company-paid', 'qa-emp-ana'});
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await waitFor(tester, find.text('Chat interno'));
      await tapText(tester, 'Mi día');
      await _logoutEmployee(tester);
    });

    testWidgets('CHAT-005 la farmacia ve la respuesta y el chat directo con Ana', (tester) async {
      await launchApp(tester);
      await loginAsCompany(tester);
      await waitFor(tester, find.text('Trabajando'), timeout: const Duration(seconds: 40));
      await tapText(tester, 'Chat');
      await waitFor(tester, find.text('Chat interno'));
      await waitFor(tester, find.textContaining('responde Ana'), timeout: const Duration(seconds: 20));
      await waitFor(tester, find.textContaining('Mensaje directo QA'), timeout: const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Inicio');
      await _logoutCompany(tester);
    });
  });
}
