// functions/src/notifications/onChatMessage.js
//
// Trigger: nuevo mensaje en una conversación.
//   conversations/{conversationId}/messages/{messageId}
// Notifica a todos los miembros de la conversación EXCEPTO al remitente.

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { db } = require('../config/firebase');
const { sendPushToUsers } = require('./sendPush');

/**
 * Devuelve el nombre visible de un userId (empleado o empresa).
 * @param {string} userId
 * @return {Promise<string>}
 */
async function displayNameFor(userId) {
  // Empleado
  const emp = await db.collection('employees').doc(userId).get();
  if (emp.exists) {
    const name = emp.get('name');
    if (name) return name;
  }
  // Empresa (farmacia)
  const comp = await db.collection('companies').doc(userId).get();
  if (comp.exists) {
    const name = comp.get('legalName');
    if (name) return name;
  }
  return 'Nuevo mensaje';
}

exports.onChatMessage = onDocumentCreated(
    'conversations/{conversationId}/messages/{messageId}',
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const msg = snap.data() || {};
      const conversationId = event.params.conversationId;
      const senderId = msg.senderId;
      const text = (msg.text || '').toString();

      if (!senderId) return;

      // Lee la conversación para obtener miembros y título.
      const convSnap = await db.collection('conversations').doc(conversationId).get();
      if (!convSnap.exists) return;
      const conv = convSnap.data() || {};

      const memberIds = Array.isArray(conv.memberIds) ? conv.memberIds : [];
      const recipients = memberIds.filter((uid) => uid && uid !== senderId);
      if (!recipients.length) return;

      const senderName = await displayNameFor(senderId);
      const isGroup = conv.isGroup === true;

      // En grupo, el título es el nombre del grupo (p.ej. "Todos"); en 1-a-1 el
      // título visible es el nombre del remitente.
      const title = isGroup ?
      `${senderName} · ${conv.title || 'Grupo'}` :
      senderName;

      // Recorta el cuerpo para la notificación.
      const body = text.length > 140 ? `${text.substring(0, 137)}…` : text;

      await sendPushToUsers({
        uids: recipients,
        title,
        body: body || 'Te ha enviado un mensaje',
        data: {
          type: 'chat_message',
          conversationId,
          senderId,
        },
      });

      logger.info(
          `onChatMessage: notificado a ${recipients.length} miembro(s) de ${conversationId}`,
      );
    },
);
