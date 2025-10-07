import 'package:farmatime/data/repositories/chat_repository_impl.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:farmatime/presentation/pages/chat/chat/chat_controller.dart';
import 'package:get/get.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<ChatRepository>(() => ChatRepositoryImpl());
    
    Get.lazyPut(() => ChatController(
      repo: Get.find<ChatRepository>(),
    ));
  }
}