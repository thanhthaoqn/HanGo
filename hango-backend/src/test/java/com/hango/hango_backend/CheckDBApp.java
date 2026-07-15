package com.hango.hango_backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

@SpringBootApplication
public class CheckDBApp {
    public static void main(String[] args) {
        SpringApplication.run(CheckDBApp.class, args);
    }
}

@Component
class Checker implements CommandLineRunner {
    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) throws Exception {
        System.out.println("====== EXAM DB CHECK ======");
        List<Map<String, Object>> list = jdbcTemplate.queryForList("SELECT e.id, e.title, COUNT(eq.question_id) as qCount FROM exams e LEFT JOIN exam_questions eq ON e.id = eq.exam_id GROUP BY e.id ORDER BY e.id DESC LIMIT 10");
        for (Map<String, Object> map : list) {
            System.out.println("Exam ID: " + map.get("id") + ", Title: " + map.get("title") + ", Questions: " + map.get("qCount"));
        }
        System.out.println("===========================");
        System.exit(0);
    }
}
