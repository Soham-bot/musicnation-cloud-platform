-- ─────────────────────────────────────────────────────────────
-- MusicNation Digital Music Cloud — Database Schema
-- Engine: MySQL 8.0
-- ─────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS musicnation_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE musicnation_db;

-- ── Users & Roles (RBAC) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS roles (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(50) NOT NULL UNIQUE,          -- admin, manager, staff
  description TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(100) NOT NULL UNIQUE,
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role_id       INT NOT NULL DEFAULT 3,             -- default: staff
  is_active     BOOLEAN DEFAULT TRUE,
  last_login    TIMESTAMP NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (role_id) REFERENCES roles(id)
);

-- ── Track Catalog ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tracks (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  title       VARCHAR(255) NOT NULL,
  artist      VARCHAR(255) NOT NULL,
  duration    VARCHAR(10),
  s3_key      VARCHAR(500),
  genre       VARCHAR(100),
  language    VARCHAR(50) DEFAULT 'Hindi',
  play_count  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT TRUE,
  added_by    INT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (added_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ── Play Events (Analytics) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS play_events (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  track_id    INT NOT NULL,
  user_id     INT,
  played_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  duration_s  INT,                                  -- seconds actually listened
  region      VARCHAR(50) DEFAULT 'ap-south-1',
  device      VARCHAR(100),
  FOREIGN KEY (track_id) REFERENCES tracks(id),
  FOREIGN KEY (user_id)  REFERENCES users(id) ON DELETE SET NULL
);

-- ── System Metrics (Monitoring) ───────────────────────────────
CREATE TABLE IF NOT EXISTS system_metrics (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  cpu_pct     DECIMAL(5,2),
  mem_pct     DECIMAL(5,2),
  disk_pct    DECIMAL(5,2),
  api_status  VARCHAR(20) DEFAULT 'ok',
  active_conn INT DEFAULT 0
);

-- ── Audit Log ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT,
  action      VARCHAR(100) NOT NULL,
  resource    VARCHAR(255),
  detail      TEXT,
  ip_address  VARCHAR(45),
  logged_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ── Seed Data ─────────────────────────────────────────────────

-- Roles
INSERT IGNORE INTO roles (name, description) VALUES
  ('admin',   'Full platform access — infrastructure, users, billing'),
  ('manager', 'Catalog management, analytics, reporting'),
  ('staff',   'Read-only catalog access, personal play history');

-- Default admin user (password: Admin@123)
INSERT IGNORE INTO users (username, email, password_hash, role_id) VALUES
  ('admin',   'admin@musicnation.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUMMTCiCs4lfCX0H1XvqQVnue', 1),
  ('manager', 'manager@musicnation.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUMMTCiCs4lfCX0H1XvqQVnue', 2),
  ('staff',   'staff@musicnation.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUMMTCiCs4lfCX0H1XvqQVnue', 3);

-- Tracks
INSERT IGNORE INTO tracks (id, title, artist, duration, s3_key, genre, language) VALUES
  (1, 'Kesariya',         'Arijit Singh',   '4:34', 'Kesariya.mp3',          'Romantic', 'Hindi'),
  (2, 'Tum Hi Ho',        'Arijit Singh',   '4:22', 'tum_hi_ho.mp3',         'Romantic', 'Hindi'),
  (3, 'Raataan Lambiyan', 'Jubin Nautiyal', '3:14', 'raataan_lambiyan.mp3',  'Romantic', 'Hindi'),
  (4, 'Apna Bana Le',     'Arijit Singh',   '4:05', 'apna_bana_le.mp3',      'Devotional','Hindi'),
  (5, 'Tera Ban Jaunga',  'Akhil Sachdeva', '3:52', 'tera_ban_jaunga.mp3',   'Romantic', 'Hindi'),
  (6, 'Dil Diyan Gallan', 'Atif Aslam',     '4:18', 'dil_diyan_gallan.mp3',  'Romantic', 'Punjabi');

-- Sample play events for analytics
INSERT IGNORE INTO play_events (track_id, user_id, duration_s, region) VALUES
  (1, 1, 274, 'ap-south-1'), (1, 2, 274, 'us-east-1'),
  (2, 1, 262, 'ap-south-1'), (2, 3, 200, 'ap-south-1'),
  (3, 2, 194, 'us-east-1'),  (4, 1, 245, 'ap-south-1'),
  (1, 3, 274, 'ap-south-1'), (5, 2, 232, 'us-east-1'),
  (6, 1, 258, 'ap-south-1'), (2, 2, 262, 'ap-south-1');

-- Sample system metrics
INSERT IGNORE INTO system_metrics (cpu_pct, mem_pct, disk_pct, api_status, active_conn) VALUES
  (23.5, 45.2, 38.1, 'ok', 12), (31.0, 47.8, 38.1, 'ok', 18),
  (19.2, 44.1, 38.2, 'ok', 8),  (55.3, 62.4, 38.3, 'ok', 34),
  (28.7, 48.9, 38.3, 'ok', 21), (22.1, 46.5, 38.4, 'ok', 15);

-- ── Workflow Tasks ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasks (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  status      ENUM('pending','in_progress','approved','rejected','done') DEFAULT 'pending',
  priority    ENUM('low','medium','high','critical') DEFAULT 'medium',
  assigned_to INT,
  created_by  INT,
  due_date    DATE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by)  REFERENCES users(id) ON DELETE SET NULL
);

-- Seed sample tasks
INSERT IGNORE INTO tasks (id, title, description, status, priority, assigned_to, created_by, due_date) VALUES
  (1, 'Upload Tera Ban Jaunga MP3',       'Missing track needs to be uploaded to S3 bucket', 'pending',     'high',     3, 1, '2026-06-25'),
  (2, 'Configure CloudFront CDN',         'Set up CloudFront distribution for audio delivery', 'in_progress', 'high',     2, 1, '2026-06-30'),
  (3, 'Enable Multi-AZ RDS',              'Migrate RDS to Multi-AZ for high availability',    'pending',     'critical', 2, 1, '2026-07-05'),
  (4, 'Setup S3 Intelligent Tiering',     'Reduce storage costs by enabling auto tiering',    'approved',    'medium',   3, 2, '2026-07-10'),
  (5, 'Add 10 new Bollywood tracks',      'Expand catalog with latest releases',               'pending',     'medium',   3, 2, '2026-07-15'),
  (6, 'Security audit — IAM permissions','Review and tighten IAM role policies',              'done',        'high',     1, 1, '2026-06-20');
