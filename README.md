# Autumn Product Manager

This is my Flutter app for In-Class Activity 13. I kept the product list from In-Class 12,
the one that reads and writes Firestore documents, and put it behind a sign-in. Firebase
Authentication holds the account. The app watches the auth state and shows either the
sign-in screen or the profile, so there is no separate navigation call after login. From
the profile you can open the products, change the password, or sign out.

## What it does

The first screen has two modes. Sign in asks for an email and a password. Register uses the
same two fields and creates the account, and Firebase signs the new user in straight away.
Both modes check that the email has an `@` and that the password is at least six characters
before they call Firebase, so a typo does not turn into a round trip. While the request is
out, the fields lock and the button shows a spinner so it cannot be tapped twice.

When something goes wrong, the app translates the Firebase error code into a sentence
instead of showing the raw exception. Sign-in failures all use the same message, even when
the email is unknown, because a more specific message would tell someone which emails have
accounts.

The profile shows the email Firebase has for the user. The password dialog asks for the
current password and the new one. If Firebase says the login is too old with
`requires-recent-login`, the service signs in again with the current password and retries
the update once. Signing out drops the app back to the form. The product list is reached
from the profile, so it disappears along with it.

## Firebase setup

The app is configured for Android. To run it against your own project:

1. Create a Firebase project and turn on Email/Password under Authentication > Sign-in
   method. Until that provider is enabled, registering and signing in both fail.
2. Register the Android app, run `flutterfire configure`, and let it write
   `lib/firebase_options.dart`.
3. Keep `firebase_core`, `firebase_auth`, and `cloud_firestore` in `pubspec.yaml`. The first
   two are the auth flow; Firestore is there because the products came from the previous
   activity.
4. Check that `android/app/src/main/AndroidManifest.xml` has the internet permission
   directly inside `<manifest>`. A release build needs it to reach Firebase.

The Firebase options in `lib/firebase_options.dart` belong to this project. If you point the
app somewhere else, regenerate that file rather than editing it by hand.

## Running it

Install the packages and start the app from the project root:

```
flutter pub get
flutter run
```

For the APK, run:

```
flutter build apk --release
```

The file ends up at `build/app/outputs/flutter-apk/app-release.apk`. I installed that exact
file on the emulator and ran the flow again before submitting, because a release build is
not the same as a debug run.

## Testing it

There is not a seeded account. I made one through the register form, since putting a
password in the repository is a bad idea. A full pass:

1. Register with a new email and a six-character password. The profile should show the email.
2. Sign out, then sign back in with the same account.
3. Submit the form empty, then with an email missing the `@` and a short password. Both
   should be caught before any request.
4. Try the wrong password. The message should be the same one an unknown email gets.
5. Change the password, sign out, sign in with the new one, and check that the old one fails.
6. Restart the app. The profile should come back without asking for the password.
7. Sign out and confirm the profile and the product list are gone.

The three unit tests in `test/widget_test.dart` cover the product search and price filter
from the previous activity. Run them with `flutter test`.
