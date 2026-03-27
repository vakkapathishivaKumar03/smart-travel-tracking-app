import sqlite3
db = 'smart_travel.db'
conn = sqlite3.connect(db)
try:
    conn.execute('ALTER TABLE users ADD COLUMN phone VARCHAR')
except sqlite3.OperationalError:
    pass
try:
    conn.execute('ALTER TABLE users ADD COLUMN password_hash VARCHAR')
except sqlite3.OperationalError:
    pass
try:
    conn.execute('ALTER TABLE users ADD COLUMN auth_provider VARCHAR DEFAULT "local"')
except sqlite3.OperationalError:
    pass
try:
    conn.execute('ALTER TABLE users ADD COLUMN created_at DATETIME')
except sqlite3.OperationalError:
    pass
conn.commit()
print('DB fixed!')
