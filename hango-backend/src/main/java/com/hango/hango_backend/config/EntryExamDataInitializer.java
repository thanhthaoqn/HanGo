package com.hango.hango_backend.config;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
@Slf4j
@Order(3)
public class EntryExamDataInitializer implements CommandLineRunner {

  private final JdbcTemplate jdbcTemplate;
  private final ObjectMapper objectMapper;

  @Data
  public static class ExamDataOption {
    private String text;
    @com.fasterxml.jackson.annotation.JsonProperty("isCorrect")
    private boolean isCorrect;
  }

  @Data
  public static class ExamDataQuestion {
    private String skill;
    private String text;
    private String explanation;
    private List<ExamDataOption> options;
  }

  @Data
  public static class ExamDataGroup {
    private String groupType;
    private String groupText;
    private List<ExamDataQuestion> questions;
  }

  @Override
  @Transactional
  public void run(String... args) throws Exception {
    log.info("Checking Entry Exam (Placement Test)...");

    Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM exams WHERE id = 1035", Integer.class);
    boolean examExists = (count != null && count > 0);

    if (examExists) {
      Integer qCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM exam_questions WHERE exam_id = 1035",
          Integer.class);
      if (qCount != null && qCount >= 40) {
        log.info("Entry Exam (id=1035) already exists with full questions. Skipping initialization.");
        return;
      } else {
        log.info("Entry Exam (id=1035) is incomplete or needs replacement. Clearing old linkages...");
        jdbcTemplate.update("DELETE FROM exam_questions WHERE exam_id = 1035");
      }
    }

    // Find system user (or any valid user) to own the exam
    Long userId = jdbcTemplate.queryForObject("SELECT MIN(id) FROM users", Long.class);
    if (userId == null) {
      log.warn("No users found in database, skipping Entry Exam initialization. Please run after user initialization.");
      return;
    }

    // Fetch System Parameters (Skills)
    Map<String, Long> skillMap = jdbcTemplate.query(
        "SELECT id, param_key FROM system_parameters WHERE param_type IN ('SKILL', 'SKILL_TYPE')",
        (rs, rowNum) -> Map.entry(rs.getString("param_key"), rs.getLong("id"))).stream()
        .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue, (a, b) -> a));

    // Fetch System Parameters (Group Types)
    Map<String, Long> groupTypeMap = jdbcTemplate.query(
        "SELECT id, param_key FROM system_parameters WHERE param_type = 'GROUP_TYPE'",
        (rs, rowNum) -> Map.entry(rs.getString("param_key"), rs.getLong("id"))).stream()
        .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue, (a, b) -> a));

    // Get difficulty (MEDIUM by default)
    List<Long> difficulties = jdbcTemplate
        .queryForList("SELECT id FROM system_parameters WHERE param_type = 'DIFFICULTY'", Long.class);
    Long diffId = difficulties.isEmpty() ? null : difficulties.get(0);

    if (examExists) {
      // Deliberately does NOT touch is_entry_exam here: a Course Manager may
      // have since un-flagged this seeded exam (or flagged others instead) via
      // the Exam Management UI, and that choice must survive app restarts.
      log.info("Updating existing Entry Exam (id=1035)...");
      jdbcTemplate.update(
          "UPDATE exams SET title = 'Global Entry Placement Test', description = 'A comprehensive exam to assess all 25 skill domains and provide a personalized learning pathway.', duration_minutes = 50, status = 'PUBLISHED', expected_question_count = 40, visibility = 'PUBLIC', passing_score = 5.0, thumbnail_url = 'https://res.cloudinary.com/diqekap4o/image/upload/v1714578160/hango-assets/exam-banner.png' WHERE id = 1035");
    } else {
      // First-time creation only: seed it as an entry exam so the feature has
      // at least one working candidate out of the box; Course Managers can
      // add more (or unflag this one) afterwards via the Exam Management UI.
      log.info("Inserting Entry Exam (id=1035)...");
      jdbcTemplate.update(
          "INSERT INTO exams (id, title, description, duration_minutes, status, expected_question_count, visibility, created_by, created_at, version, passing_score, thumbnail_url, is_entry_exam) "
              +
              "VALUES (1035, 'Global Entry Placement Test', 'A comprehensive exam to assess all 25 skill domains and provide a personalized learning pathway.', 50, 'PUBLISHED', 40, 'PUBLIC', ?, NOW(), 'v1.0', 5.0, 'https://res.cloudinary.com/diqekap4o/image/upload/v1714578160/hango-assets/exam-banner.png', TRUE)",
          userId);
    }

    List<ExamDataGroup> groups = objectMapper.readValue(getExamJson(), new TypeReference<List<ExamDataGroup>>() {
    });

    double scorePerQuestion = 10.0 / 40.0;
    int orderIndex = 1;

    for (ExamDataGroup group : groups) {
      Long groupId = null;
      if (group.getGroupType() != null) {
        Long groupTypeParamId = groupTypeMap.get(group.getGroupType());
        if (groupTypeParamId == null) {
          log.warn("Missing group type parameter: {}", group.getGroupType());
          continue;
        }

        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
          PreparedStatement ps = connection.prepareStatement(
              "INSERT INTO question_groups (context_text, group_type_param_id) VALUES (?, ?)",
              Statement.RETURN_GENERATED_KEYS);
          ps.setString(1, group.getGroupText());
          ps.setLong(2, groupTypeParamId);
          return ps;
        }, keyHolder);
        groupId = keyHolder.getKey().longValue();
      }

      for (ExamDataQuestion q : group.getQuestions()) {
        Long skillId = skillMap.get(q.getSkill());
        if (skillId == null) {
          log.warn("Missing skill parameter: {}", q.getSkill());
          if (!skillMap.isEmpty()) {
            skillId = skillMap.values().iterator().next();
          }
        }

        KeyHolder qKeyHolder = new GeneratedKeyHolder();
        Long finalGroupId = groupId;
        Long finalSkillId = skillId;
        jdbcTemplate.update(connection -> {
          PreparedStatement ps = connection.prepareStatement(
              "INSERT INTO questions (question_text, explanation, created_by, difficulty_param_id, skill_param_id, group_id, status, created_at, updated_at, question_code) "
                  +
                  "VALUES (?, ?, ?, ?, ?, ?, 'PUBLISHED', NOW(), NOW(), 'ENTRY-Q')",
              Statement.RETURN_GENERATED_KEYS);
          ps.setString(1, q.getText());
          ps.setString(2, q.getExplanation());
          ps.setLong(3, userId);
          if (diffId != null)
            ps.setLong(4, diffId);
          else
            ps.setNull(4, java.sql.Types.BIGINT);
          if (finalSkillId != null)
            ps.setLong(5, finalSkillId);
          else
            ps.setNull(5, java.sql.Types.BIGINT);
          if (finalGroupId != null)
            ps.setLong(6, finalGroupId);
          else
            ps.setNull(6, java.sql.Types.BIGINT);
          return ps;
        }, qKeyHolder);
        Long questionId = qKeyHolder.getKey().longValue();

        // Generate ExamQuestion linkage
        jdbcTemplate.update(
            "INSERT INTO exam_questions (exam_id, question_id, question_order) VALUES (?, ?, ?)",
            1035, questionId, orderIndex++);

        // Insert Options
        for (ExamDataOption opt : q.getOptions()) {
          jdbcTemplate.update(
              "INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)",
              questionId, opt.getText(), opt.isCorrect());
        }
      }
    }

    log.info("Entry Exam (id=1035) successfully generated with 40 questions.");
  }

  private String getExamJson() {
    return """
        [
          {
            "groupType": null,
            "groupText": null,
            "questions": [
              {
                "skill": "PHONETICS",
                "text": "Mark the word whose underlined part is pronounced differently from that of the others.",
                "explanation": "'heat' is pronounced as /i:/, the rest are /e/.",
                "options": [
                  {"text": "h_ea_d", "isCorrect": false},
                  {"text": "br_ea_d", "isCorrect": false},
                  {"text": "h_ea_t", "isCorrect": true},
                  {"text": "d_ea_d", "isCorrect": false}
                ]
              },
              {
                "skill": "WORD_ORDER",
                "text": "Choose the best option to complete the sentence: She bought ______.",
                "explanation": "Adjective order: OSASCOMP - beautiful (Opinion), old (Age), Vietnamese (Origin), wooden (Material). Correct is beautiful old Vietnamese wooden.",
                "options": [
                  {"text": "a beautiful wooden old Vietnamese table", "isCorrect": false},
                  {"text": "a beautiful old Vietnamese wooden table", "isCorrect": true},
                  {"text": "an old beautiful wooden Vietnamese table", "isCorrect": false},
                  {"text": "a wooden beautiful old Vietnamese table", "isCorrect": false}
                ]
              },
              {
                "skill": "PREPOSITION",
                "text": "My parents are completely opposed ______ my decision to study abroad.",
                "explanation": "be opposed to + V-ing/N.",
                "options": [
                  {"text": "with", "isCorrect": false},
                  {"text": "against", "isCorrect": false},
                  {"text": "to", "isCorrect": true},
                  {"text": "about", "isCorrect": false}
                ]
              },
              {
                "skill": "COLLOCATION",
                "text": "It is important to ______ a good impression when you go for a job interview.",
                "explanation": "make a good impression on someone.",
                "options": [
                  {"text": "do", "isCorrect": false},
                  {"text": "create", "isCorrect": false},
                  {"text": "make", "isCorrect": true},
                  {"text": "build", "isCorrect": false}
                ]
              },
              {
                "skill": "TO_INFINITIVE",
                "text": "We decided ______ at home instead of going out for dinner.",
                "explanation": "decide + to V.",
                "options": [
                  {"text": "to stay", "isCorrect": true},
                  {"text": "staying", "isCorrect": false},
                  {"text": "stay", "isCorrect": false},
                  {"text": "stayed", "isCorrect": false}
                ]
              },
              {
                "skill": "QUANTIFIER",
                "text": "I have ______ money left, so we can go out for a coffee if you like.",
                "explanation": "'a little' means some (positive), whereas 'little' means almost none (negative).",
                "options": [
                  {"text": "little", "isCorrect": false},
                  {"text": "a few", "isCorrect": false},
                  {"text": "a little", "isCorrect": true},
                  {"text": "few", "isCorrect": false}
                ]
              },
              {
                "skill": "PHRASAL_VERB",
                "text": "The meeting was ______ because of the sudden heavy rain.",
                "explanation": "put off = postponed.",
                "options": [
                  {"text": "put out", "isCorrect": false},
                  {"text": "put off", "isCorrect": true},
                  {"text": "taken off", "isCorrect": false},
                  {"text": "turned down", "isCorrect": false}
                ]
              },
              {
                "skill": "PREPOSITIONAL_PHRASE",
                "text": "______ my surprise, she didn't show up at the party.",
                "explanation": "To one's surprise = surprisingly.",
                "options": [
                  {"text": "In", "isCorrect": false},
                  {"text": "To", "isCorrect": true},
                  {"text": "With", "isCorrect": false},
                  {"text": "For", "isCorrect": false}
                ]
              },
              {
                "skill": "CONVERSATION_ORDERING",
                "text": "Tom: 'How about going to the cinema tonight?' - Mary: '______'",
                "explanation": "Responding to a suggestion.",
                "options": [
                  {"text": "That's a good idea.", "isCorrect": true},
                  {"text": "No, thanks. I'm full.", "isCorrect": false},
                  {"text": "You're welcome.", "isCorrect": false},
                  {"text": "Never mind.", "isCorrect": false}
                ]
              },
              {
                "skill": "LETTER_ORDERING",
                "text": "Choose the correct order to form a logical letter.\\na. I look forward to hearing from you soon.\\nb. Dear Sir/Madam,\\nc. I am writing to apply for the position of Marketing Manager.\\nd. Yours faithfully,",
                "explanation": "b - c - a - d is the standard formal letter structure.",
                "options": [
                  {"text": "b - a - c - d", "isCorrect": false},
                  {"text": "b - c - a - d", "isCorrect": true},
                  {"text": "c - b - a - d", "isCorrect": false},
                  {"text": "b - c - d - a", "isCorrect": false}
                ]
              }
            ]
          },
          {
            "groupType": "NOTICE_COMPLETION",
            "groupText": "IMPORTANT NOTICE FOR ALL STAFF\\nDue to scheduled maintenance, the main elevator will be (11)______ from 8 AM to 12 PM this Saturday. Please use the stairs or the service elevator at the back of the building. We apologize for any inconvenience (12)______ by this disruption.",
            "questions": [
              {
                "skill": "VOCABULARY",
                "text": "Choose the correct word for blank (11).",
                "explanation": "out of order = not working, unavailable fits best.",
                "options": [
                  {"text": "unavailable", "isCorrect": true},
                  {"text": "impossible", "isCorrect": false},
                  {"text": "unacceptable", "isCorrect": false},
                  {"text": "incapable", "isCorrect": false}
                ]
              },
              {
                "skill": "PASSIVE_VOICE",
                "text": "Choose the correct word for blank (12).",
                "explanation": "caused is the reduced relative clause for passive voice 'which is caused'.",
                "options": [
                  {"text": "causing", "isCorrect": false},
                  {"text": "caused", "isCorrect": true},
                  {"text": "cause", "isCorrect": false},
                  {"text": "to cause", "isCorrect": false}
                ]
              }
            ]
          },
          {
            "groupType": "LEAFLET_ADVERTISEMENT",
            "groupText": "WANT TO LEARN SPANISH?\\nJoin our intensive weekend courses!\\n- Taught by native speakers (13)______ have years of teaching experience.\\n- Small class sizes guarantee personalized attention.\\n- Special discounts for early birds (14)______ before Friday.\\nDon't miss out on this (15)______ opportunity!",
            "questions": [
              {
                "skill": "RELATIVE_CLAUSE",
                "text": "Choose the correct word for blank (13).",
                "explanation": "'who' refers to people (native speakers).",
                "options": [
                  {"text": "which", "isCorrect": false},
                  {"text": "who", "isCorrect": true},
                  {"text": "whom", "isCorrect": false},
                  {"text": "whose", "isCorrect": false}
                ]
              },
              {
                "skill": "REDUCED_RELATIVE_CLAUSE",
                "text": "Choose the correct word for blank (14).",
                "explanation": "'registering' is the present participle reducing the active relative clause 'who register'.",
                "options": [
                  {"text": "registered", "isCorrect": false},
                  {"text": "registering", "isCorrect": true},
                  {"text": "register", "isCorrect": false},
                  {"text": "to register", "isCorrect": false}
                ]
              },
              {
                "skill": "VOCABULARY",
                "text": "Choose the correct word for blank (15).",
                "explanation": "'excellent' fits the context of an opportunity.",
                "options": [
                  {"text": "terrible", "isCorrect": false},
                  {"text": "excellent", "isCorrect": true},
                  {"text": "ordinary", "isCorrect": false},
                  {"text": "average", "isCorrect": false}
                ]
              }
            ]
          },
          {
            "groupType": "PARAGRAPH_TEXT_REORDERING",
            "groupText": "Put the sentences in the correct order to form a logical paragraph.\\na. First, we visited the famous Eiffel Tower.\\nb. Finally, we enjoyed a romantic dinner on a boat along the Seine river.\\nc. My trip to Paris last summer was unforgettable.\\nd. After that, we spent hours walking through the Louvre Museum.",
            "questions": [
              {
                "skill": "PARAGRAPH_ORDERING",
                "text": "Which is the correct order?",
                "explanation": "Topic sentence (c) -> First (a) -> After that (d) -> Finally (b).",
                "options": [
                  {"text": "c - a - d - b", "isCorrect": true},
                  {"text": "a - d - b - c", "isCorrect": false},
                  {"text": "c - d - a - b", "isCorrect": false},
                  {"text": "c - a - b - d", "isCorrect": false}
                ]
              },
              {
                "skill": "PARAGRAPH_ORDERING",
                "text": "Identify the topic sentence of the ordered paragraph.",
                "explanation": "Sentence c introduces the main subject.",
                "options": [
                  {"text": "Sentence a", "isCorrect": false},
                  {"text": "Sentence b", "isCorrect": false},
                  {"text": "Sentence c", "isCorrect": true},
                  {"text": "Sentence d", "isCorrect": false}
                ]
              }
            ]
          },
          {
            "groupType": "GUIDED_CLOZE_TEST",
            "groupText": "Global warming is the long-term heating of Earth's climate system observed since the pre-industrial period due to human activities, primarily fossil fuel burning, (18)______ increases heat-trapping greenhouse gas levels in Earth's atmosphere. The term is frequently used interchangeably with the term climate change, (19)______ the latter refers to both human- and naturally produced warming. It is most commonly measured as the average increase in Earth's global surface temperature.\\nSince the pre-industrial period, human activities are estimated to have increased Earth's global average temperature. It is unequivocal that human influence has warmed the atmosphere, ocean, and land. We need to (20)______ immediate action. If we (21)______ to ignore this, the consequences will be severe. A lot of rare species are (22)______ the verge of extinction.",
            "questions": [
              {
                "skill": "RELATIVE_CLAUSE",
                "text": "Choose the correct word for blank (18).",
                "explanation": "'which' is a relative pronoun for the preceding clause/noun phrase.",
                "options": [
                  {"text": "who", "isCorrect": false},
                  {"text": "that", "isCorrect": false},
                  {"text": "which", "isCorrect": true},
                  {"text": "where", "isCorrect": false}
                ]
              },
              {
                "skill": "CONTEXTUAL_MEANING",
                "text": "Choose the correct word for blank (19).",
                "explanation": "'though' or 'although' indicates contrast.",
                "options": [
                  {"text": "because", "isCorrect": false},
                  {"text": "so", "isCorrect": false},
                  {"text": "though", "isCorrect": true},
                  {"text": "despite", "isCorrect": false}
                ]
              },
              {
                "skill": "COLLOCATION",
                "text": "Choose the correct word for blank (20).",
                "explanation": "Collocation: take action.",
                "options": [
                  {"text": "do", "isCorrect": false},
                  {"text": "make", "isCorrect": false},
                  {"text": "take", "isCorrect": true},
                  {"text": "have", "isCorrect": false}
                ]
              },
              {
                "skill": "PHRASAL_VERB",
                "text": "Choose the correct word for blank (21).",
                "explanation": "'go on' means continue.",
                "options": [
                  {"text": "give up", "isCorrect": false},
                  {"text": "go on", "isCorrect": true},
                  {"text": "put off", "isCorrect": false},
                  {"text": "turn out", "isCorrect": false}
                ]
              },
              {
                "skill": "PREPOSITION",
                "text": "Choose the correct word for blank (22).",
                "explanation": "Prepositional phrase: on the verge of.",
                "options": [
                  {"text": "in", "isCorrect": false},
                  {"text": "at", "isCorrect": false},
                  {"text": "on", "isCorrect": true},
                  {"text": "by", "isCorrect": false}
                ]
              }
            ]
          },
          {
            "groupType": "READING_COMPREHENSION_8_QUESTIONS",
            "groupText": "Sleep is a crucial part of our daily routine, accounting for about one-third of our time. It is increasingly clear that sleep is essential for the healthy functioning of both the brain and the rest of the body. During sleep, our bodies rest, but our brains are surprisingly active, carrying out processes that prepare us for the next day.\\n\\nThere are two main types of sleep: Rapid Eye Movement (REM) sleep and non-REM sleep. Non-REM sleep has three distinct stages. Stage 1 is light sleep, where you drift in and out of wakefulness. Stage 2 is slightly deeper sleep, during which your heart rate slows and your body temperature drops. Stage 3 is deep sleep, the most restorative stage, necessary for feeling refreshed in the morning. REM sleep, on the other hand, is when most dreaming occurs. It usually starts about 90 minutes after you fall asleep.\\n\\nChronic sleep deprivation has serious consequences. It impairs cognitive functions such as memory, attention, and decision-making. Moreover, it is linked to a higher risk of physical health problems, including heart disease, obesity, and diabetes. Therefore, adults should aim for 7 to 9 hours of quality sleep per night.",
            "questions": [
              {
                "skill": "MAIN_IDEA_CENTRAL_THEME_QUESTION",
                "text": "What is the main idea of the passage?",
                "explanation": "The passage primarily discusses the importance of sleep, its stages, and the consequences of lack of sleep.",
                "options": [
                  {"text": "How to treat sleep disorders.", "isCorrect": false},
                  {"text": "The different types of dreams.", "isCorrect": false},
                  {"text": "The importance and nature of sleep.", "isCorrect": true},
                  {"text": "Why REM sleep is dangerous.", "isCorrect": false}
                ]
              },
              {
                "skill": "FACTUAL_DETAIL_QUESTION",
                "text": "According to the passage, how much of our time does sleep roughly account for?",
                "explanation": "First sentence: 'accounting for about one-third of our time'.",
                "options": [
                  {"text": "One-half", "isCorrect": false},
                  {"text": "One-third", "isCorrect": true},
                  {"text": "One-quarter", "isCorrect": false},
                  {"text": "Two-thirds", "isCorrect": false}
                ]
              },
              {
                "skill": "REFERENCE_QUESTION",
                "text": "The word 'It' in paragraph 2 refers to ______.",
                "explanation": "The preceding subject is REM sleep.",
                "options": [
                  {"text": "Stage 3", "isCorrect": false},
                  {"text": "Deep sleep", "isCorrect": false},
                  {"text": "REM sleep", "isCorrect": true},
                  {"text": "Non-REM sleep", "isCorrect": false}
                ]
              },
              {
                "skill": "SYNONYM_IN_CONTEXT",
                "text": "The word 'crucial' in paragraph 1 is closest in meaning to ______.",
                "explanation": "Crucial means very important.",
                "options": [
                  {"text": "unnecessary", "isCorrect": false},
                  {"text": "important", "isCorrect": true},
                  {"text": "complex", "isCorrect": false},
                  {"text": "simple", "isCorrect": false}
                ]
              },
              {
                "skill": "FACTUAL_DETAIL_QUESTION",
                "text": "In which stage of sleep does the body temperature drop?",
                "explanation": "Paragraph 2 states 'Stage 2 is slightly deeper sleep, during which your heart rate slows and your body temperature drops.'",
                "options": [
                  {"text": "Stage 1", "isCorrect": false},
                  {"text": "Stage 2", "isCorrect": true},
                  {"text": "Stage 3", "isCorrect": false},
                  {"text": "REM sleep", "isCorrect": false}
                ]
              },
              {
                "skill": "ANTONYM_IN_CONTEXT",
                "text": "The word 'chronic' in paragraph 3 is opposite in meaning to ______.",
                "explanation": "Chronic means long-lasting, opposite is short-term or temporary.",
                "options": [
                  {"text": "temporary", "isCorrect": true},
                  {"text": "severe", "isCorrect": false},
                  {"text": "continuous", "isCorrect": false},
                  {"text": "harmful", "isCorrect": false}
                ]
              },
              {
                "skill": "TRUE_NOT_TRUE_QUESTION",
                "text": "Which of the following is NOT TRUE according to the passage?",
                "explanation": "Our brains are active, not inactive, during sleep.",
                "options": [
                  {"text": "Stage 3 is necessary for feeling refreshed.", "isCorrect": false},
                  {"text": "Adults need 7 to 9 hours of sleep.", "isCorrect": false},
                  {"text": "Our brains are completely inactive during sleep.", "isCorrect": true},
                  {"text": "Lack of sleep can lead to heart disease.", "isCorrect": false}
                ]
              },
              {
                "skill": "INFERENCE_QUESTION",
                "text": "It can be inferred from the passage that ______.",
                "explanation": "Since lack of sleep is linked to health problems, maintaining good sleep habits is beneficial.",
                "options": [
                  {"text": "You should wake up during Stage 3 to feel rested.", "isCorrect": false},
                  {"text": "People who sleep less than 7 hours are likely to perform worse on cognitive tasks.", "isCorrect": true},
                  {"text": "Dreams only happen during non-REM sleep.", "isCorrect": false},
                  {"text": "Physical exercise guarantees deep sleep.", "isCorrect": false}
                ]
              }
            ]
          },
          {
            "groupType": "READING_COMPREHENSION_10_QUESTIONS",
            "groupText": "Artificial Intelligence (AI) has become an integral part of modern society, transforming how we work, communicate, and live. From voice assistants on our smartphones to recommendation algorithms on streaming platforms, AI is everywhere. However, the rapid advancement of this technology brings both incredible opportunities and significant challenges.\\n\\nOne of the primary benefits of AI is its ability to automate repetitive tasks, thereby increasing efficiency and allowing humans to focus on more complex, creative endeavors. For instance, in manufacturing, robots driven by AI can assemble products much faster and with greater precision than human workers. In healthcare, AI algorithms are being used to analyze medical images, helping doctors detect diseases like cancer at earlier, more treatable stages.\\n\\nDespite these advantages, the rise of AI has sparked concerns about the future of employment. Many fear that machines will eventually replace human workers across various industries, leading to widespread job losses. While new jobs will undoubtedly be created to manage and develop AI systems, the transition could leave many individuals without the necessary skills to compete in a tech-driven economy.\\n\\nFurthermore, the issue of data privacy cannot be ignored. AI systems require vast amounts of data to learn and improve. This data often includes personal information collected from users, raising alarms about how this data is stored, shared, and potentially misused. To mitigate these risks, experts emphasize the need for robust ethical guidelines and strict government regulations to ensure that AI is developed and deployed responsibly.",
            "questions": [
              {
                "skill": "MAIN_IDEA_CENTRAL_THEME_QUESTION",
                "text": "What is the primary theme of the passage?",
                "explanation": "The passage discusses both the benefits and the challenges/risks of AI.",
                "options": [
                  {"text": "The history of Artificial Intelligence.", "isCorrect": false},
                  {"text": "The impacts of AI on modern society, including its pros and cons.", "isCorrect": true},
                  {"text": "How to learn programming for AI.", "isCorrect": false},
                  {"text": "Why AI should be completely banned.", "isCorrect": false}
                ]
              },
              {
                "skill": "FACTUAL_DETAIL_QUESTION",
                "text": "According to paragraph 2, how does AI benefit the healthcare sector?",
                "explanation": "It analyzes medical images to help detect diseases early.",
                "options": [
                  {"text": "By replacing doctors completely.", "isCorrect": false},
                  {"text": "By prescribing medications automatically.", "isCorrect": false},
                  {"text": "By assisting doctors in detecting diseases early through image analysis.", "isCorrect": true},
                  {"text": "By building hospitals faster.", "isCorrect": false}
                ]
              },
              {
                "skill": "FACTUAL_DETAIL_QUESTION",
                "text": "What is a major concern related to employment mentioned in paragraph 3?",
                "explanation": "People fear AI will replace human workers.",
                "options": [
                  {"text": "AI systems will demand higher salaries.", "isCorrect": false},
                  {"text": "Machines might replace human workers leading to job losses.", "isCorrect": true},
                  {"text": "Humans will not want to work anymore.", "isCorrect": false},
                  {"text": "The government will heavily tax new jobs.", "isCorrect": false}
                ]
              },
              {
                "skill": "PARAPHRASING_QUESTION",
                "text": "Which of the following best paraphrases this sentence: 'AI systems require vast amounts of data to learn and improve'?",
                "explanation": "AI needs large data sets to function effectively.",
                "options": [
                  {"text": "AI systems only work if they have a small amount of data.", "isCorrect": false},
                  {"text": "Huge quantities of information are necessary for AI to develop and get better.", "isCorrect": true},
                  {"text": "Data is not important for AI systems to improve.", "isCorrect": false},
                  {"text": "Learning and improving AI requires human intelligence, not data.", "isCorrect": false}
                ]
              },
              {
                "skill": "REFERENCE_QUESTION",
                "text": "The word 'This data' in paragraph 4 refers to ______.",
                "explanation": "The vast amounts of data required for AI to learn.",
                "options": [
                  {"text": "Personal information", "isCorrect": true},
                  {"text": "AI systems", "isCorrect": false},
                  {"text": "Government regulations", "isCorrect": false},
                  {"text": "Ethical guidelines", "isCorrect": false}
                ]
              },
              {
                "skill": "SYNONYM_IN_CONTEXT",
                "text": "The word 'mitigate' in paragraph 4 is closest in meaning to ______.",
                "explanation": "Mitigate means to make less severe.",
                "options": [
                  {"text": "increase", "isCorrect": false},
                  {"text": "reduce", "isCorrect": true},
                  {"text": "ignore", "isCorrect": false},
                  {"text": "encourage", "isCorrect": false}
                ]
              },
              {
                "skill": "PARAGRAPH_SPECIFIC_INFORMATION_QUESTION",
                "text": "What specific solution is proposed in the final paragraph to handle privacy risks?",
                "explanation": "Ethical guidelines and government regulations.",
                "options": [
                  {"text": "Stopping the use of the internet completely.", "isCorrect": false},
                  {"text": "Implementing robust ethical guidelines and strict regulations.", "isCorrect": true},
                  {"text": "Hiring more human workers.", "isCorrect": false},
                  {"text": "Deleting all personal data immediately.", "isCorrect": false}
                ]
              },
              {
                "skill": "TRUE_NOT_TRUE_QUESTION",
                "text": "Which statement is TRUE according to the passage?",
                "explanation": "AI automates repetitive tasks to let humans focus on creativity.",
                "options": [
                  {"text": "AI has no practical application in manufacturing.", "isCorrect": false},
                  {"text": "AI frees humans to focus on complex and creative tasks.", "isCorrect": true},
                  {"text": "The transition to a tech-driven economy will be effortless for everyone.", "isCorrect": false},
                  {"text": "Data privacy is no longer a concern with modern AI.", "isCorrect": false}
                ]
              },
              {
                "skill": "INFERENCE_QUESTION",
                "text": "It can be inferred from the passage that in the future, workers will most likely need to ______.",
                "explanation": "They will need new skills to compete in a tech-driven economy.",
                "options": [
                  {"text": "acquire new technological skills to remain employable.", "isCorrect": true},
                  {"text": "stop using smartphones.", "isCorrect": false},
                  {"text": "work entirely without machines.", "isCorrect": false},
                  {"text": "move to the healthcare sector.", "isCorrect": false}
                ]
              },
              {
                "skill": "VOCABULARY",
                "text": "The word 'integral' in paragraph 1 is closest in meaning to ______.",
                "explanation": "Integral means essential.",
                "options": [
                  {"text": "optional", "isCorrect": false},
                  {"text": "essential", "isCorrect": true},
                  {"text": "unusual", "isCorrect": false},
                  {"text": "temporary", "isCorrect": false}
                ]
              }
            ]
          }
        ]
        """;
  }
}
