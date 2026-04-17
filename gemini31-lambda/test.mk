test:
	@VAR="hello"; if [ -n "$$VAR" ]; then echo "$$VAR"; fi
