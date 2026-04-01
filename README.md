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
   - Ou importez vos produits en masse via **Importer CSV**.
3. Ouvrez le produit : affichez le **QR** (JSON signé HMAC).
4. **Caisse** → **Scanner un QR** : scannez l’écran ou un QR imprimé ; option anti-fraude puis ajout au panier.
5. **Encaisser** → **Valider la vente** : PDF de facture ; les **Stocks** et **Factures** se mettent à jour.

## Import initial de 2000 produits (CSV/Excel)

### Option la plus simple: CSV

1. Exportez vos produits depuis le système existant (ERP/logiciel caisse/Excel) en **CSV**.
2. Dans l’app: onglet **Produits** → **Importer CSV**.
3. L’app valide puis fait un **bulk upsert** scoppé par `companyId` (multi-tenant).

### Format CSV attendu

En-têtes obligatoires:
- `name`
- `price`
- `stock`

Colonnes optionnelles:
- `id` (si vous voulez réutiliser un identifiant interne)
- `sku` (recommandé pour relier facilement au système existant)
- `description`

Exemple:

```csv
id,sku,name,price,stock,description
P-0001,SKU-123,Coca 33cl,0.80,120,Canette
P-0002,SKU-999,Eau 1.5L,0.60,80,Bouteille
```

Notes:
- `companyId` **n’est jamais lu depuis le fichier** : il est appliqué par la session (isolation SaaS).
- `price` accepte `0.80` ou `0,80`.

## Synchronisation du stock avec le système existant (API)

### Stratégie recommandée (production)

- **Checkout côté serveur (Cloud Functions)**:
  - L’app envoie la vente (companyId + lignes: productId/sku + qty).
  - La Cloud Function:
    - décrémente le stock dans Firestore (transaction)
    - appelle l’API du système existant (webhook/ERP) avec une authentification (bearer/HMAC)
    - retourne un statut OK/KO à l’app

Pourquoi: évite les divergences si un téléphone est hors-ligne ou compromis.

### Ce qui est déjà prêt dans le code

- **Import CSV**: `lib/features/products/import_products_screen.dart` + `lib/core/utils/csv_products_parser.dart`
- **Bulk upsert**: `ProductsRepository.bulkUpsert(companyId, products)`
- **Flux checkout**: `lib/data/sales_repository.dart` (démo local)
- **Hook API** (optionnel): `ExternalStockSync` (`lib/core/services/external_stock_sync.dart`)

## Passer à Firebase (plus tard)

- Ajoutez `firebase_core`, `cloud_firestore`, `firebase_auth`, etc.
- Remplacez `InMemoryProductsRepository` par une implémentation Firestore avec chemins du type `companies/{companyId}/products/...`.
- Les opérations critiques de stock devraient idéalement passer par **Cloud Functions** + appel à l’API du système existant.
