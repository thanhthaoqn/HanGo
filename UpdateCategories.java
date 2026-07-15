import java.sql.*;

public class UpdateCategories {
    public static void main(String[] args) {
        String url = "jdbc:mysql://hango-mysql-db-hango.c.aivencloud.com:20612/defaultdb?sslMode=REQUIRED";
        String user = "avnadmin";
        String password = "AVNS_lWEa-I_FbTsXPE6890X";
        
        try (Connection conn = DriverManager.getConnection(url, user, password);
             Statement stmt = conn.createStatement()) {
             
            stmt.executeUpdate("ALTER TABLE questions MODIFY category_id BIGINT NULL");
            stmt.executeUpdate("UPDATE questions SET category_id = NULL");
            stmt.executeUpdate("DELETE FROM question_categories");
            stmt.executeUpdate("INSERT INTO question_categories (name) VALUES ('Read and Fill in a Notice')");
            stmt.executeUpdate("INSERT INTO question_categories (name) VALUES ('Read and Fill in a Leaflet/Advertisement')");
            stmt.executeUpdate("INSERT INTO question_categories (name) VALUES ('Paragraph/Text Reordering')");
            stmt.executeUpdate("INSERT INTO question_categories (name) VALUES ('Guided Cloze Test')");
            stmt.executeUpdate("INSERT INTO question_categories (name) VALUES ('Reading Comprehension - 8 questions')");
            stmt.executeUpdate("INSERT INTO question_categories (name) VALUES ('Reading Comprehension - 10 questions')");
            System.out.println("Categories updated successfully!");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
