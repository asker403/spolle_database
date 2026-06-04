const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const collectionName = "sanatcilar";

async function deleteCollection() {
  console.log(`🧹 Fetching all documents in collection "${collectionName}"...`);
  const snapshot = await db.collection(collectionName).get();
  
  if (snapshot.empty) {
    console.log("ℹ️ No documents found to delete.");
    return;
  }

  console.log(`🗑️ Found ${snapshot.size} documents to delete. Starting batch deletion...`);
  
  const documents = snapshot.docs;
  const BATCH_SIZE = 400;
  let deletedCount = 0;

  for (let i = 0; i < documents.length; i += BATCH_SIZE) {
    const chunk = documents.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    
    chunk.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    deletedCount += chunk.length;
    console.log(`✅ Deleted batch: ${deletedCount}/${documents.length} documents`);
  }

  console.log(`🎉 Collection "${collectionName}" successfully cleared!`);
}

deleteCollection().catch(err => {
  console.error("❌ Error clearing collection:", err);
  process.exit(1);
});
