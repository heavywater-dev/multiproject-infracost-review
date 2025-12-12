## {{PROJECT_NAME}}

{{#HAS_RESOURCES}}
| Resource | Type | Monthly Cost Change |
|----------|------|---------------------|
{{#RESOURCES}}
| {{NAME}} | {{TYPE}} | {{COST_CHANGE}} |
{{/RESOURCES}}

**Total change for this project:** {{PROJECT_COST_CHANGE}}
{{/HAS_RESOURCES}}

{{#NO_RESOURCES}}
No resource changes in this project.
{{/NO_RESOURCES}}

---
