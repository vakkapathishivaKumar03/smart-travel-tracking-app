import sqlite3
try:
    conn = sqlite3.connect('smart_travel.db')
    conn.execute('CREATE TABLE users_new (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL, email VARCHAR UNIQUE, phone VARCHAR UNIQUE, password_hash VARCHAR, auth_provider VARCHAR DEFAULT "local", created_at DATETIME)')
    conn.execute('INSERT INTO users_new (id, name, email, phone, password_hash, auth_provider, created_at) SELECT id, name, email, phone, password_hash, auth_provider, created_at FROM users')
    conn.execute('DROP TABLE users')
    conn.execute('ALTER TABLE users_new RENAME TO users')
    conn.commit()
    print("Migration successful")
except Exception as e:
    print("Error:", e)
