import java.sql.*;

public class CheckCategories {
    public static void main(String[] args) {
        String url = "jdbc:mysql://hango-hango-tech.d.aivencloud.com:13670/defaultdb";
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection conn = DriverManager.getConnection(url, "avnadmin", "AVNS_lWEa-I_FbTsXPE6890X")) {
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery("SELECT * FROM question_categories");
                while (rs.next()) {
                    System.out.println("ID: " + rs.getLong("id") + ", Name: " + rs.getString("name"));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
