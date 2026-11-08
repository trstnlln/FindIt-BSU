import 'package:flutter_test/flutter_test.dart';
import 'package:finditbsu_app/models/item_model.dart';
import 'package:finditbsu_app/providers/auth_provider.dart';
import 'package:finditbsu_app/services/matching_service.dart';

void main() {
  group('AuthProvider Domain Validation', () {
    test('strictly enforces @g.batstate-u.edu.ph institutional domain', () {
      expect(AuthProvider.isBatStateUEmail('random@gmail.com'), isFalse);
      expect(AuthProvider.isBatStateUEmail('user@yahoo.com'), isFalse);
      expect(AuthProvider.isBatStateUEmail('test@batstate-u.edu.ph'), isFalse);
      expect(AuthProvider.isBatStateUEmail('john@outlook.com'), isFalse);
      expect(AuthProvider.isBatStateUEmail('21-12345@g.batstate-u.edu.ph'), isTrue);
      expect(AuthProvider.isBatStateUEmail('student.name@g.batstate-u.edu.ph'), isTrue);
    });
  });

  group('ItemModel Features', () {
    test('serializes and deserializes new campus custody and anti-fraud fields', () {
      final now = DateTime(2026, 11, 5, 12, 0);
      final item = ItemModel(
        id: 'doc-123',
        type: 'found',
        title: 'Blue Hydroflask Tumbler',
        description: 'Navy blue 32oz tumbler with BatState-U sticker on front',
        category: 'Water Bottle / Tumbler',
        location: 'College of Informatics & Computing Sciences',
        specificLocation: '3rd Floor Rm 304',
        custodyLocation: 'Gate 1 Guard Post',
        verificationQuestion: 'What specific sticker is beside the logo?',
        date: now,
        photoUrl: 'https://storage.googleapis.com/test.jpg',
        status: 'open',
        ownerId: 'user-456',
        createdAt: now,
      );

      final map = item.toMap();
      expect(map['specificLocation'], '3rd Floor Rm 304');
      expect(map['custodyLocation'], 'Gate 1 Guard Post');
      expect(map['verificationQuestion'], 'What specific sticker is beside the logo?');

      final reconstructed = ItemModel.fromMap(map, 'doc-123');
      expect(reconstructed.id, 'doc-123');
      expect(reconstructed.specificLocation, '3rd Floor Rm 304');
      expect(reconstructed.custodyLocation, 'Gate 1 Guard Post');
      expect(reconstructed.verificationQuestion, 'What specific sticker is beside the logo?');
      expect(reconstructed.title, 'Blue Hydroflask Tumbler');
    });

    test('copyWith properly updates new fields', () {
      final now = DateTime(2026, 11, 5);
      const original = ItemModel(
        id: '1',
        type: 'found',
        title: 'Keys',
        description: 'Set of 3 keys on a red lanyard',
        category: 'Keys',
        location: 'Library',
        date: DateTime(2026, 11, 5),
        status: 'open',
        ownerId: 'u1',
        createdAt: DateTime(2026, 11, 5),
      );

      final updated = original.copyWith(
        custodyLocation: 'Library Front Desk',
        specificLocation: '2nd Floor Quiet Zone',
        verificationQuestion: 'What cartoon character is on the keychain?',
      );

      expect(updated.custodyLocation, 'Library Front Desk');
      expect(updated.specificLocation, '2nd Floor Quiet Zone');
      expect(updated.verificationQuestion, 'What cartoon character is on the keychain?');
      expect(updated.title, 'Keys');
    });
  });

  group('MatchingService Similarity Scoring', () {
    test('computes higher similarity score for proximate items in same category and location', () {
      final now = DateTime(2026, 11, 5);

      final lostItem = ItemModel(
        id: 'lost-1',
        type: 'lost',
        title: 'Black Casio Scientific Calculator',
        description: 'fx-991EX classwiz calculator with name written in marker',
        category: 'Electronics',
        location: 'College of Engineering',
        date: now,
        status: 'open',
        ownerId: 'student-a',
        createdAt: now,
      );

      final matchingFoundItem = ItemModel(
        id: 'found-1',
        type: 'found',
        title: 'Casio Calculator found in CEAFA Room 201',
        description: 'Black scientific calculator left behind on armchair',
        category: 'Electronics',
        location: 'College of Engineering',
        date: now,
        status: 'open',
        ownerId: 'student-b',
        createdAt: now,
      );

      final unrelatedFoundItem = ItemModel(
        id: 'found-2',
        type: 'found',
        title: 'Red Windbreaker Jacket',
        description: 'Large varsity windbreaker jacket',
        category: 'Clothing',
        location: 'Gymnasium',
        date: now.subtract(const Duration(days: 30)),
        status: 'open',
        ownerId: 'student-c',
        createdAt: now,
      );

      final matchScore = MatchingService.calculateMatchScore(lostItem, matchingFoundItem);
      final unrelatedScore = MatchingService.calculateMatchScore(lostItem, unrelatedFoundItem);

      // Same category (40) + same location (25) + same date (20) + keywords (10+) = 85+
      expect(matchScore, greaterThan(70));
      expect(unrelatedScore, equals(0));
      expect(matchScore, greaterThan(unrelatedScore));
    });
  });
}
