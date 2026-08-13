import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class UpdatePayments {
    public static void main(String[] args) {
        String url = "jdbc:mysql://hango-mysql-db-hango.c.aivencloud.com:20612/defaultdb?sslMode=REQUIRED";
        String user = "avnadmin";
        String pass = "AVNS_lWEa-I_FbTsXPE6890X";

        try {
            Connection conn = DriverManager.getConnection(url, user, pass);
            System.out.println("Connected to database.");

            // Get all payment IDs
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT id FROM payments WHERE status = 'SUCCESS'");
            List<Long> ids = new ArrayList<>();
            while (rs.next()) {
                ids.add(rs.getLong("id"));
            }
            System.out.println("Found " + ids.size() + " successful payments.");

            if (ids.isEmpty()) {
                System.out.println("No payments found. Exiting.");
                conn.close();
                return;
            }

            // June 1, 2026 to August 13, 2026
            long startMillis = LocalDateTime.of(2026, 6, 1, 0, 0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
            long endMillis = LocalDateTime.of(2026, 8, 13, 23, 59).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
            Random rand = new Random();

            PreparedStatement updateStmt = conn.prepareStatement("UPDATE payments SET created_at = ? WHERE id = ?");
            for (Long id : ids) {
                long randomMillis = startMillis + (long) (rand.nextDouble() * (endMillis - startMillis));
                Timestamp randomTimestamp = new Timestamp(randomMillis);
                
                updateStmt.setTimestamp(1, randomTimestamp);
                updateStmt.setLong(2, id);
                updateStmt.addBatch();
            }

            int[] results = updateStmt.executeBatch();
            System.out.println("Updated " + results.length + " payments with random dates between June 2026 and August 2026.");
            
            conn.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
