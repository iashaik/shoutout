import 'package:shoutout/shoutout.dart';

void main() async {
  // 1. Create configuration
  final config = ShoutoutConfig(
    baseUrl: 'https://yoursite.frappe.cloud',
    connectTimeout: const Duration(seconds: 30),
    maxRetries: 3,
    enableLogging: true,
  );

  // 2. Initialize client
  final client = ShoutoutClient(config: config);

  // 3. Authenticate
  client.setApiCredentials('your_api_key', 'your_api_secret');
  // OR use bearer token
  // client.setToken('your_bearer_token');

  try {
    // Example 1: Call a Frappe method
    print('===== Calling Frappe Method =====');
    final user = await client.callMethod(
      'frappe.auth.get_logged_user',
      params: {'include_roles': true},
    );
    print('Logged in user: $user');

    // Example 2: Get a document
    print('\n===== Getting Document =====');
    final userDoc = await client.getDoc(
      'User',
      'user@example.com',
      fields: ['name', 'email', 'full_name', 'enabled'],
    );
    print('User document: $userDoc');

    // Example 3: Get list of documents
    print('\n===== Getting Document List =====');
    final users = await client.getList(
      'User',
      fields: ['name', 'email', 'full_name'],
      filters: {'enabled': 1},
      limitPageLength: 10,
      orderBy: 'creation desc',
    );
    print('Found ${users.length} users');

    // Example 4: Create a document
    print('\n===== Creating Document =====');
    final newUser = await client.createDoc(
      'User',
      data: {
        'email': 'newuser@example.com',
        'first_name': 'John',
        'last_name': 'Doe',
      },
    );
    print('Created user: $newUser');

    // Example 5: Update a document
    print('\n===== Updating Document =====');
    final updated = await client.updateDoc(
      'User',
      'user@example.com',
      data: {
        'mobile_no': '+1234567890',
      },
    );
    print('Updated user: $updated');

    // Example 6: Delete a document
    print('\n===== Deleting Document =====');
    await client.deleteDoc('User', 'user@example.com');
    print('Document deleted successfully');
  } on AuthenticationException catch (e) {
    print('Authentication failed: ${e.message}');
  } on NetworkException catch (e) {
    print('No internet connection: ${e.message}');
  } on NotFoundException catch (e) {
    print('Document not found: ${e.message}');
  } on FrappeException catch (e) {
    print('Frappe error: ${e.serverMessage}');
    print('Exception details: ${e.exc}');
  } on ShoutoutException catch (e) {
    print('General error: ${e.message}');
    if (e.statusCode != null) {
      print('Status code: ${e.statusCode}');
    }
  } finally {
    // Clean up
    client.dispose();
  }
}
