import os
import shutil

print(f"gcloud: {shutil.which('gcloud')}")
print(f"PATH: {os.environ.get('PATH')}")
