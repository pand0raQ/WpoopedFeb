#!/bin/bash

# Script to help update Firebase security rules

echo "===== Firebase Security Rules Update Helper ====="
echo ""
echo "Follow these steps to update your Firebase security rules:"
echo ""
echo "1. Go to the Firebase Console: https://console.firebase.google.com/"
echo "2. Select your project: 'wpoopedfeb'"
echo "3. In the left sidebar, click on 'Firestore Database'"
echo "4. Click on the 'Rules' tab"
echo "5. Replace the existing rules with the following:"
echo ""
echo "----------------------------------------"
cat firestore_rules.txt
echo "----------------------------------------"
echo ""
echo "6. Click 'Publish' to save the rules"
echo ""
echo "After updating the rules, restart your app and try again."
echo "The permissions issue should be resolved."
echo ""
echo "If you still encounter permission issues, check the following:"
echo "1. Make sure you're properly authenticated with Apple Sign In"
echo "2. Make sure the ownerID field in your documents matches your user ID"
echo "3. Check the Firebase console logs for any errors"
echo ""
echo "===== End of Instructions =====" 