import 'package:flutter_test/flutter_test.dart';
import 'package:hango/domain/model/trainer_ai_question_models.dart';

void main() {
  group('TrainerAiSubQuestion.fromJson', () {
    test('parses skillParamId and difficultyId when the AI/backend provides them', () {
      final json = {
        'questionText': 'What is the main idea of the passage?',
        'explanation': 'The passage mainly discusses...',
        'skillParamId': 101,
        'difficultyId': 15,
        'options': [
          {'optionText': 'A', 'isCorrect': true},
          {'optionText': 'B', 'isCorrect': false},
        ],
      };

      final sub = TrainerAiSubQuestion.fromJson(json);

      expect(sub.skillParamId, 101);
      expect(sub.difficultyId, 15);
      expect(sub.questionText, 'What is the main idea of the passage?');
      expect(sub.options.length, 2);
    });

    test('leaves skillParamId and difficultyId null when omitted', () {
      final json = {
        'questionText': 'Who is the main character?',
        'options': <Map<String, dynamic>>[],
      };

      final sub = TrainerAiSubQuestion.fromJson(json);

      expect(sub.skillParamId, isNull);
      expect(sub.difficultyId, isNull);
    });
  });

  group('TrainerAiGenerateResponse.fromJson (MULTIPLE mode)', () {
    test('parses per-subQuestion skill/difficulty ids end-to-end', () {
      final json = {
        'mode': 'MULTIPLE',
        'group': {
          'passageText': 'Once upon a time...',
          'categoryId': 1,
          'difficultyId': 14,
          'subQuestions': [
            {
              'questionText': 'Q1',
              'skillParamId': 101,
              'difficultyId': 15,
              'options': [
                {'optionText': 'A', 'isCorrect': true},
              ],
            },
            {
              'questionText': 'Q2',
              'options': [
                {'optionText': 'A', 'isCorrect': true},
              ],
            },
          ],
        },
      };

      final resp = TrainerAiGenerateResponse.fromJson(json);

      expect(resp.mode, 'MULTIPLE');
      expect(resp.group, isNotNull);
      expect(resp.group!.subQuestions.length, 2);
      expect(resp.group!.subQuestions[0].skillParamId, 101);
      expect(resp.group!.subQuestions[0].difficultyId, 15);
      expect(resp.group!.subQuestions[1].skillParamId, isNull);
      expect(resp.group!.subQuestions[1].difficultyId, isNull);
    });
  });
}
