# flutter\_learner\_admin\_app



\## Firebase Setup



This repository does \*\*not\*\* include Firebase configuration files because they contain private company credentials.



Before running the application, obtain the required Firebase configuration files from your project administrator or create them using your own Firebase project.



\### Required Files



\#### Android



Place the Firebase configuration file in:



```text

android/app/google-services.json

```



\#### iOS (if applicable)



Place the Firebase configuration file in:



```text

ios/Runner/GoogleService-Info.plist

```



\#### Flutter Firebase Configuration



Generate the Firebase configuration using the FlutterFire CLI:



```bash

dart pub global activate flutterfire\_cli

flutterfire configure

```



This command will generate:



```text

lib/firebase\_options.dart

```



\## Install Dependencies



```bash

flutter pub get

```



\## Run the Application



```bash

flutter run

```



\## Security Notice



For security reasons, the following files are \*\*not included\*\* in this public repository:



\- `android/app/google-services.json`

\- `ios/Runner/GoogleService-Info.plist`

\- `lib/firebase\_options.dart`

\- `serviceAccountKey.json`



If you are a project contributor, request these files from the project administrator before running the application.

