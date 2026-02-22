const { onRequest } = require('firebase-functions/v2/https');
const functions = require('firebase-functions'); // 如需使用 functions.logger 可保留
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

admin.initializeApp();
const db = admin.firestore();

exports.createUserWithRole = onRequest({ timeoutSeconds: 30 }, async (req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).send('Missing or invalid Authorization header');
    }

    const idToken = authHeader.split('Bearer ')[1];

    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      const requesterUid = decoded.uid;

      const requesterDoc = await db.collection('users').doc(requesterUid).get();
      if (!requesterDoc.exists) {
        return res.status(403).send('Requester not found');
      }

      const requesterRole = requesterDoc.data().role;
      const { email, password, name, role } = req.body;

      if (!email || !password || !name || !role) {
        return res.status(400).send('Missing required fields');
      }

      // 權限檢查
      if (requesterRole === 'Admin') {
        if (!['Manager', 'Editor', 'Viewer'].includes(role)) {
          return res.status(403).send('Admin 可新增 Manager/Editor/Viewer');
        }
      } else if (requesterRole === 'Manager') {
        if (!['Editor', 'Viewer'].includes(role)) {
          return res.status(403).send('Manager 只能新增 Editor/Viewer');
        }
      } else {
        return res.status(403).send('您無權建立使用者');
      }

      // 暱稱檢查
      const nameDup = await db.collection('users').where('name', '==', name).get();
      if (!nameDup.empty) {
        return res.status(409).send('暱稱已存在');
      }

      // 建立帳號（檢查信箱是否重複）
      let userRecord;
      try {
        userRecord = await admin.auth().createUser({ email, password });
      } catch (err) {
        if (err.code === 'auth/email-already-exists') {
          return res.status(409).send('Email 已存在');
        }
        console.error('⚠️ 建立使用者錯誤:', err);
        return res.status(500).send('建立 Firebase 帳號失敗：' + err.message);
      }

      // 寫入 Firestore
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email,
        name,
        role,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.status(200).send('使用者建立成功');
    } catch (error) {
      console.error('❌ createUserWithRole error:', error);
      return res.status(500).send('Server Error: ' + error.message);
    }
  });
});

exports.deleteUser = onRequest({ timeoutSeconds: 30 }, async (req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).send('Missing or invalid Authorization header');
    }

    const idToken = authHeader.split('Bearer ')[1];

    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      const requesterUid = decoded.uid;

      const requesterDoc = await db.collection('users').doc(requesterUid).get();
      if (!requesterDoc.exists) {
        return res.status(403).send('Requester not found');
      }

      const requesterRole = requesterDoc.data().role;
      const { uid, role: targetRole } = req.body;

      if (!uid || !targetRole) {
        return res.status(400).send('Missing required fields (uid, role)');
      }

      // 權限檢查
      if (requesterRole === 'Admin') {
        if (!['Manager', 'Editor', 'Viewer'].includes(targetRole)) {
          return res.status(403).send('Admin 只能刪除 Manager/Editor/Viewer');
        }
      } else if (requesterRole === 'Manager') {
        if (!['Editor', 'Viewer'].includes(targetRole)) {
          return res.status(403).send('Manager 只能刪除 Editor/Viewer');
        }
      } else {
        return res.status(403).send('您無權刪除使用者');
      }

      // 刪除 Firebase Authentication 帳號
      await admin.auth().deleteUser(uid);

      // 刪除 Firestore 使用者文件
      await db.collection('users').doc(uid).delete();

      return res.status(200).send('使用者刪除成功');
    } catch (error) {
      console.error('❌ deleteUser error:', error);
      return res.status(500).send('Server Error: ' + error.message);
    }
  });
});
