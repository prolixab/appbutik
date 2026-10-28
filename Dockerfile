# The published store as a static site, for hosting on Coolify.
# Built by .github/workflows/publish.yml after scripts/build-repo.sh has filled site/.
FROM nginx:1.27-alpine
COPY site/ /usr/share/nginx/html/
