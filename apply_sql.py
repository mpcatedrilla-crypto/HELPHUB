import psycopg2
import sys

# The direct DB connection URL (bypassing pooler if region is unknown)
DB_URL = "postgresql://postgres:Marck080105*@db.tqclrsjrbyjfagdgijpy.supabase.co:5432/postgres"

def main():
    try:
        print("Connecting to Supabase...")
        conn = psycopg2.connect(DB_URL)
        conn.autocommit = True
        cursor = conn.cursor()
        
        print("Reading SQL file...")
        with open(r"C:\Users\Marck\.gemini\antigravity\brain\4bc1047f-158f-445d-91ad-84e3c876a41d\supabase_schema.sql", "r", encoding="utf-8") as f:
            sql = f.read()
            
        print("Executing SQL script...")
        cursor.execute(sql)
        print("Successfully created tables, functions, and RLS policies!")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
