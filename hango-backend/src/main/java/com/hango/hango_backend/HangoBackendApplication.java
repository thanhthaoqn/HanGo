package com.hango.hango_backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootApplication
public class HangoBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(HangoBackendApplication.class, args);
	}

}
