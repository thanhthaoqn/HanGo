package com.hango.hango_backend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class HangoBackendApplicationTests {

	@org.springframework.beans.factory.annotation.Autowired
	private javax.sql.DataSource dataSource;

	@Test
	void contextLoads() {
		try (java.sql.Connection conn = dataSource.getConnection()) {
			System.out.println("=== QUIZ/PRACTICE LESSONS AND THEIR QUESTION COUNTS ===");
			try (java.sql.Statement stmt = conn.createStatement();
				 java.sql.ResultSet rs = stmt.executeQuery(
					 "SELECT l.id, l.title, l.lesson_type, " +
					 " (SELECT COUNT(*) FROM lesson_quizzes lq WHERE lq.lesson_id = l.id) as q_count FROM lessons l WHERE l.lesson_type IN ('quiz', 'practice')"
				 )) {
				while (rs.next()) {
					System.out.println("Lesson ID: " + rs.getLong("id") + ", Title: " + rs.getString("title") +
							", Type: " + rs.getString("lesson_type") + ", Question Count: " + rs.getInt("q_count"));
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

}
