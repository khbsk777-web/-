/* ガチャマップ：みんなで共有するモードの設定
   Firebase のコンソール →「プロジェクトの設定」→「マイアプリ」→ ウェブアプリの firebaseConfig をここに入れます。
   ここに入る値は、公開しても問題ない「アプリの名札」です（パスワードではありません）。
   守りは Firestore のルールと「承認済みドメイン」「APIキーの制限」で行います。
   null のままだと、各端末の中だけに保存するモードで動きます。 */
window.GACHA_FIREBASE = null;
/* 例：
window.GACHA_FIREBASE = {
  apiKey: "AIza....",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project",
  appId: "1:1234567890:web:abcdef"
};
*/
