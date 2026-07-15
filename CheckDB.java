import java.sql.*;

public class CheckDB {
    public static void main(String[] args) {
        String url = "jdbc:mysql://hango-hango-tech.d.aivencloud.com:13670/defaultdb";
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection conn = DriverManager.getConnection(url, "avnadmin", "AVNS_lWEa-I_FbTsXPE6890X")) {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery("SELECT e.id, e.title, COUNT(eq.question_id) as qCount FROM exams e LEFT JOIN exam_questions eq ON e.id = eq.exam_id GROUP BY e.id ORDER BY e.id DESC LIMIT 5");
                while (rs.next()) {
                    System.out.println("Exam ID: " + rs.getLong("id") + ", Title: " + rs.getString("title") + ", Questions: " + rs.getInt("qCount"));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
