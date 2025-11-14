import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:get/get.dart';

class InboxController extends GetxController {
  final ChatRepository repo;
  final Rx<String?> currentUserId = Rx<String?>(null);
  final Rx<String?> companyId = Rx<String?>(null);

  InboxController({
    required this.repo,
  });

  final conversations = Rxn<List<Conversation>>();
  final isLoading = true.obs;
  final error = RxnString();

  final Brain brain = Get.find<Brain>();

  @override
  void onInit() {
    super.onInit();

    currentUserId.value = brain.company.value?.id == null
        ? brain.employee.value!.uid
        : brain.company.value!.id;

    companyId.value = brain.company.value?.id ?? brain.employee.value!.companyId;
    
    _listen();
  }

  void _listen() {
    isLoading.value = true;
    repo.streamInbox(currentUserId.value!, companyId.value!).listen((list) {
      conversations.value = list;
      isLoading.value = false;
    }, onError: (e) {
      error.value = e.toString();
      isLoading.value = false;
    });
  }
}
