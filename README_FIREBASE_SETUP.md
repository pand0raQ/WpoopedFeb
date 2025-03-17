# Firebase Setup Instructions

## Fixing the "Missing or insufficient permissions" Error

If you're seeing the error "Missing or insufficient permissions" when trying to access Firestore data, you need to update your Firebase security rules. Follow these steps:

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. In the left sidebar, click on "Firestore Database"
4. Click on the "Rules" tab
5. Replace the existing rules with the following:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && (request.auth.uid == userId || request.auth.token.sub == userId);
    }
    
    // Allow users to read and write their own dogs
    match /dogs/{dogId} {
      allow read, write: if request.auth != null && (
        // Owner can read/write
        resource.data.ownerID == request.auth.uid || 
        resource.data.ownerID == request.auth.token.sub ||
        // For new documents
        request.resource.data.ownerID == request.auth.uid ||
        request.resource.data.ownerID == request.auth.token.sub ||
        // Shared dogs
        (resource.data.isShared == true && exists(/databases/$(database)/documents/shares/{shareId}))
      );
    }
    
    // Allow users to read and write their own walks
    match /walks/{walkId} {
      allow read, write: if request.auth != null && (
        // Owner can read/write
        resource.data.ownerID == request.auth.uid ||
        resource.data.ownerID == request.auth.token.sub ||
        // For new documents
        request.resource.data.ownerID == request.auth.uid ||
        request.resource.data.ownerID == request.auth.token.sub
      );
    }
    
    // Allow users to read and write shares they're involved in
    match /shares/{shareId} {
      allow read, write: if request.auth != null && (
        resource.data.sharedByEmail == request.auth.token.email ||
        resource.data.sharedWithEmail == request.auth.token.email ||
        request.resource.data.sharedByEmail == request.auth.token.email ||
        request.resource.data.sharedWithEmail == request.auth.token.email
      );
    }
  }
}
```

6. Click "Publish" to save the rules

## Understanding the Rules

These rules allow:

1. Users to read and write their own user data
2. Users to read and write their own dogs
3. Users to read and write their own walks
4. Users to read and write shares they're involved in

The rules use both Firebase Auth UID (`request.auth.uid`) and Apple Sign In ID (`request.auth.token.sub`) to support both authentication methods.

## Testing the Rules

After updating the rules, restart your app and try again. If you still encounter permission issues, check the following:

1. Make sure you're properly authenticated with either Firebase Auth or Apple Sign In
2. Make sure the `ownerID` field in your documents matches your user ID
3. Check the Firebase console logs for any errors

## Temporary Solution

Until you fix the security rules, the app will use sample data in offline mode so you can still test the functionality. 