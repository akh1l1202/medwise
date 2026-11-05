import os
import csv
import sqlite3
import time
import re

csv_path = os.path.expandvars(r'%USERPROFILE%\Downloads\A_Z_medicines_dataset_of_India.csv')
if not os.path.exists(csv_path):
    print(f"Error: {csv_path} does not exist!")
    exit(1)

out_db = os.path.join('assets', 'database', 'indian_medicines.db')
temp_db = os.path.join('assets', 'database', 'indian_medicines_temp.db')

if os.path.exists(temp_db):
    os.remove(temp_db)

print(f"Reading A-Z Medicine Dataset from: {csv_path}")
print(f"Target DB: {out_db}")

conn = sqlite3.connect(temp_db)
cur = conn.cursor()

# SQLite optimizations for fast bulk insert
cur.execute('PRAGMA synchronous = OFF')
cur.execute('PRAGMA journal_mode = MEMORY')

cur.execute('''
    CREATE TABLE medicines (
        id INTEGER PRIMARY KEY,
        brand_name TEXT NOT NULL,
        active_salt TEXT NOT NULL,
        strength TEXT,
        manufacturer TEXT,
        dosage_form TEXT,
        common_symptoms TEXT
    )
''')

cur.execute('''
    CREATE VIRTUAL TABLE medicines_fts USING fts5(
        brand_name,
        active_salt,
        content='medicines',
        content_rowid='id'
    )
''')

def parse_composition(c1, c2):
    s1 = c1.strip() if c1 else ''
    s2 = c2.strip() if c2 else ''
    if s1 and s2:
        full = f"{s1} + {s2}"
    else:
        full = s1 or s2
    
    # Extract strength from parentheses e.g. "Amoxycillin (500mg)"
    strengths = re.findall(r'\(([^)]+)\)', full)
    strength_str = ' + '.join(strengths) if strengths else ''
    
    # Clean salt name
    salt_str = re.sub(r'\([^)]*\)', '', full).strip()
    salt_str = re.sub(r'\s+', ' ', salt_str).strip(' +')
    
    return salt_str, strength_str

def parse_form(name, pack):
    combo = f"{name} {pack}".lower()
    if 'tablet' in combo or 'tab' in combo:
        return 'Tablet'
    elif 'capsule' in combo or 'cap' in combo:
        return 'Capsule'
    elif 'syrup' in combo or 'suspension' in combo or 'syp' in combo or 'liquid' in combo or 'susp' in combo:
        return 'Syrup'
    elif 'injection' in combo or 'inj' in combo or 'vial' in combo:
        return 'Injection'
    elif 'eye drop' in combo or 'ear drop' in combo or 'drops' in combo or 'drop' in combo:
        return 'Drops'
    elif 'cream' in combo or 'gel' in combo or 'ointment' in combo or 'oint' in combo:
        return 'Ointment'
    elif 'inhaler' in combo or 'respule' in combo or 'rotacap' in combo or 'spray' in combo:
        return 'Inhaler'
    return 'Tablet'

t0 = time.time()
batch = []
count = 0

with open(csv_path, 'r', encoding='utf-8', errors='ignore') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Filter discontinued medicines
        if row.get('Is_discontinued', '').strip().upper() == 'TRUE':
            continue
        
        name = row.get('name', '').strip()
        if not name:
            continue
        
        c1 = row.get('short_composition1', '')
        c2 = row.get('short_composition2', '')
        salt, strength = parse_composition(c1, c2)
        if not salt:
            salt = "Allopathic Formulation"
            
        mfr = row.get('manufacturer_name', '').strip()
        pack = row.get('pack_size_label', '').strip()
        form = parse_form(name, pack)
        
        count += 1
        batch.append((count, name, salt, strength, mfr, form, ''))
        
        if len(batch) >= 10000:
            cur.executemany('INSERT INTO medicines VALUES (?,?,?,?,?,?,?)', batch)
            batch = []
            if count % 50000 == 0:
                print(f"Processed {count} medicines...")

if batch:
    cur.executemany('INSERT INTO medicines VALUES (?,?,?,?,?,?,?)', batch)

print(f"Total inserted medicines: {count}. Building indexes...")
cur.execute('CREATE INDEX idx_brand_name ON medicines(brand_name)')
cur.execute('CREATE INDEX idx_active_salt ON medicines(active_salt)')

print("Building FTS5 index...")
cur.execute('''
    INSERT INTO medicines_fts(rowid, brand_name, active_salt)
    SELECT id, brand_name, active_salt FROM medicines
''')

conn.commit()
conn.close()

t1 = time.time()
size_mb = os.path.getsize(temp_db) / (1024 * 1024)
print(f"Finished building temporary database in {t1 - t0:.2f} seconds. File size: {size_mb:.2f} MB")

# Replace target DB
if os.path.exists(out_db):
    os.remove(out_db)
os.rename(temp_db, out_db)

print(f"Successfully generated {out_db} with {count} Indian medicines!")
