import psycopg2
import sys

DB_URL = "postgresql://postgres:Marck080105*@db.tqclrsjrbyjfagdgijpy.supabase.co:5432/postgres"

def main():
    try:
        print("Connecting to Supabase...")
        conn = psycopg2.connect(DB_URL)
        conn.autocommit = True
        cursor = conn.cursor()
        
        print("Executing SQL script...")
        # Add new enum value
        cursor.execute("ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'pending_confirmation';")
        
        # Add new columns to reports table
        cursor.execute("ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_resolution_notes TEXT;")
        cursor.execute("ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_proof_url TEXT;")
        
        print("Successfully updated database schema!")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
