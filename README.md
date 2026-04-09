# TPE QR SaaS

Application Flutter (Material 3, Riverpod) pour vente par QR sécurisé (HMAC), anti-fraude ML Kit, panier et factures PDF. **Mode démo** : données en mémoire, pas de Firebase requis pour tester sur téléphone.

## Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), `flutter doctor` sans erreur bloquante.
- Sur Android : [pilote USB / débogage USB](https://developer.android.com/studio/debug/dev-options) activé sur le téléphone.

## Première installation du projet

Dans un terminal, à la racine du dossier `tpe_qr_saas` :

```powershell
cd $env:USERPROFILE\Desktop\tpe_qr_saas
flutter create . --project-name tpe_qr_saas --org com.example.tpeqr
```

Cette commande crée ou complète les dossiers `android/`, `ios/`, etc. sans écraser votre code dans `lib/`.

Puis :

```powershell
flutter pub get
```

### Permission caméra (Android)

Après `flutter create`, ouvrez `android/app/src/main/AndroidManifest.xml` et assurez-vous d’avoir au minimum :

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

`flutter create` peut déjà inclure d’autres permissions ; gardez aussi `INTERNET` si vous ajoutez Firebase plus tard.

## Lancer l’app sur votre téléphone

1. Branchez le téléphone en USB (ou utilisez le débogage sans fil si configuré).
2. `flutter devices` — vérifiez que l’appareil apparaît.
3. `flutter run -d <id_appareil>`  
   ou `flutter run` si un seul appareil est connecté.

Build APK de test :

```powershell
flutter build apk --debug
```

Le fichier est sous `build\app\outputs\flutter-apk\app-debug.apk` (à installer manuellement si besoin).

## Parcours de test rapide

1. **Connexion** : gardez les valeurs par défaut ou le même `Company ID` partout.
2. **Produits** : créez un produit (prix, stock), ajoutez une **photo de référence** pour tester l’anti-fraude.
3. Ouvrez le produit : affichez le **QR** (JSON signé HMAC).
4. **Caisse** → **Scanner un QR** : scannez l’écran ou un QR imprimé ; option anti-fraude puis ajout au panier.
5. **Encaisser** → **Valider la vente** : PDF de facture ; les **Stocks** et **Factures** se mettent à jour.

## Passer à Firebase (plus tard)

- Ajoutez `firebase_core`, `cloud_firestore`, `firebase_auth`, etc.
- Remplacez `InMemoryProductsRepository` par une implémentation Firestore avec chemins du type `companies/{companyId}/products/...`.
- Les opérations critiques de stock devraient idéalement passer par **Cloud Functions**.
