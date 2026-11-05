# Firebase setup (PanganPutar production)

This app now builds its production path on Firebase Auth + Firestore +
Cloud Functions + Storage. Demo mode remains available when
`PRODUCTION_MODE` is not `true`.

## Required public config (Flutter)

Create `config/firebase.production.json` from
`config/firebase.example.json` and fill the public Firebase web/app values:

```sh
flutter build web --release --no-web-resources-cdn \\
  --dart-define-from-file=config/firebase.production.json
```

Never put a service account, Midtrans server key, or AWS secret in this
file. Those stay in Cloud Functions.

## Firebase project

1. Create a Firebase project and enable Blaze billing for Cloud Functions.
2. Enable Authentication → Google (and configure OAuth consent + SHA-1/256
   for Android).
3. Create Firestore in production mode and deploy
   `firebase/firestore.rules` + `firebase/firestore.indexes.json`.
4. Deploy Storage rules (`firebase/storage.rules`).
5. Deploy functions:
   ```sh
   cd firebase/functions
   npm install
   npm run build
   cd ..
   firebase deploy --only functions,firestore,storage
   ```

## Cloud Functions secrets

Set with `firebase functions:secrets:set` (or the console):

- `MIDTRANS_SERVER_KEY`
- `MIDTRANS_IS_PRODUCTION` (`true`/`false`)
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `AWS_REKOGNITION_COLLECTION` (default `panganputar-faces`)

## Face verification honesty

This build sends a selfie to `verifyFace`. The server calls AWS
Rekognition (`SearchFacesByImage`, then `IndexFaces`) and stores only the
face reference/template in the collection; the raw image is not persisted.
Certified liveness detection is not implemented in this repository. For
stronger assurance, integrate AWS Rekognition Face Liveness or another
PAD-certified provider before claiming identity-grade verification.

## Status

No Firebase project, AWS collection, or Midtrans server key is present in
this repository, so the production path cannot be end-to-end tested here.
`flutter analyze`, `flutter test`, and `flutter build web --release` only
prove compilation and local behavior.
