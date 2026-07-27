/// 3 fallback suggested questions to display when chatbox is empty.
/// When the learner sends a message, backend will generate context-aware suggestedQuestions.
List<String> defaultLessonAiSuggestedQuestions() => const [
  'Can you give me an overview of this lesson?',
  'What are the key takeaways from this lesson?',
  'Can you provide a real-world example or practical application?',
];
