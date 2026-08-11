CREATE TABLE IF NOT EXISTS certificates (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL,
    credential_id VARCHAR(50) NOT NULL,
    issued_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_certificates_user_course UNIQUE (user_id, course_id),
    CONSTRAINT uk_certificates_credential_id UNIQUE (credential_id),
    CONSTRAINT fk_certificates_user
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_certificates_course
        FOREIGN KEY (course_id) REFERENCES courses (id)
);
