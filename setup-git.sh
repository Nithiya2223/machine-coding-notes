#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./setup-git.sh https://github.com/yourname/fullstack-machine-coding-course.git"
  exit 1
fi
REPO_URL=$1
git init
git add .
git commit -m "🚀 Full Stack Machine Coding Course — Zero to Interview Ready (React + Node + Express + PostgreSQL)

Modules:
- 00: Foundations (REST, DB Design, React Patterns, Auth)
- 01: Core Full Stack Questions (5 problems)
- 02: Product Feature Questions (6 problems)
- 03: Company-Specific Questions (8 problems — Razorpay, Swiggy, Atlassian, Freshworks, Postman, Stripe)
- 04: Advanced Questions (5 problems)
- 05: API Design Challenges (4 problems)
- 06: Database Design Challenges (4 problems)
- 07: Twists & Extensions Master Catalog
- 08: Strategy & Tips
- 09: Mock Rounds (3 full mocks — Easy/Medium/Hard)

Every problem includes:
✅ Database schema (SQL) with ER diagram
✅ Complete API design (all endpoints, request/response)
✅ Full React frontend code
✅ Full Node/Express backend code
✅ End-to-end flow diagram
✅ 6 interviewer twists with code snippets
✅ 5 real interview Q&As per problem
✅ Time budget breakdown"

git remote add origin $REPO_URL
git branch -M main
git push -u origin main
echo "✅ Course pushed to $REPO_URL"
