import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_KEY")

client = create_client(url, key)
print("SUPABASE CLIENT OK")

with open("hello.txt", "w", encoding="utf-8") as f:
    f.write("hello supabase")

with open("hello.txt", "rb") as f:
    result = client.storage.from_("test").upload(
        path="hello.txt",
        file=f,
        file_options={"content-type": "text/plain"}
    )

print("UPLOAD RESULT =", result)