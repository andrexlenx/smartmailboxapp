@echo off
curl -X POST "https://firestore.googleapis.com/v1/projects/smartmailbox-caiotta/databases/(default)/documents/mailbox_events" ^
-H "Content-Type: application/json" ^
-d "{
  \"fields\": {
    \"date\": { \"stringValue\": \"2023-10-26 14:15\" },
    \"type\": { \"stringValue\": \"Pacco Amazon\" },
    \"weight\": { \"integerValue\": 1250 }
  }
}"