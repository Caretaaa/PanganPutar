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
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (optional —
  only for the AWS Rekognition image path)
- `AWS_REKOGNITION_COLLECTION` (default `panganputar-faces`)
- `FACE_EMBED_MATCH_THRESHOLD` (default `0.42` — cosine, tune on pilot data)

## Face verification: two paths

### On-device embedding (default on Android, no AWS needed)

`DeviceFaceVerificationService` (Android only):

1. Google ML Kit detects exactly one reasonably sized face in the selfie.
2. TFLite MobileFaceNet (`assets/tflite/mobilefacenet.tflite`) computes a
   192-d L2-normalized embedding on-device.
3. **Only the embedding vector** is uploaded to the `verifyFace` Cloud
   Function. The raw selfie never leaves the device.
4. The server runs 1:N cosine matching over the private
   `face_embeddings` Firestore collection (weekly quota 4 porsi / 2 orders
   per identity, ISO week in Asia/Jakarta).

Honest limits: no certified liveness/PAD; the embedding is as trustworthy
as the client. 1:N matching is a Firestore scan — fine at pilot scale,
but move to a vector index at thousands of identities.

### AWS Rekognition image path (requires AWS credentials)

If the client sends `imageBase64` and AWS credentials are configured, the
server calls AWS Rekognition (`SearchFacesByImage`, then `IndexFaces`)
and stores only the face reference/template; the raw image is not
persisted. For stronger assurance, integrate AWS Rekognition Face
Liveness or another PAD-certified provider before claiming
identity-grade verification.

None of this replaces proper liveness or identity docs — that is where
AWS/Azure Face Liveness or manual review is recommended before claiming certified identity verification.

## Status

No Firebase project, AWS collection, or Midtrans server key is present in
this repository, so the production path cannot be end-to-end tested here.
`flutter analyze`, `flutter test`, and `flutter build web --release` only
prove compilation and local behavior.
