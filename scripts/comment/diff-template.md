<details>
<summary><strong>📁 {{PROJECT_NAME}} - {{PROJECT_COST_CHANGE}}</strong></summary>

{{#HAS_RESOURCES}}

### 🔄 **Resource Changes**

{{#RESOURCES}}

> **{{NAME}}**  
> `{{TYPE}}`  
> 💰 {{COST_CHANGE}}

{{/RESOURCES}}

### 📊 **Project Total**

```
{{PROJECT_COST_CHANGE}}
```

{{/HAS_RESOURCES}}

{{#NO_RESOURCES}}

> ✅ **No resource changes** in this project

{{/NO_RESOURCES}}

</details>

---
