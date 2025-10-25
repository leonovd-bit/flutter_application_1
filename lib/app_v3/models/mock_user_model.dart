// Mock user model for design mode
class MockUser {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;

  const MockUser({
    this.uid = 'mock_user_123',
    this.displayName = 'Design Mode User',
    this.email = 'designmode@example.com',
    this.photoUrl = 'https://ui-avatars.com/api/?name=Design+User',
  });
}

const mockUser = MockUser();
