
cd $HOME/gemini-cli-aws/gemini31-lightsail
export GOOGLE_API_KEY=$GOOGLE_API_KEY
export GEMINI_API_KEY=$GOOGLE_API_KEY
export GEMINI_KEY=$GOOGLE_API_KEY

source .env

python3 list_models.py
