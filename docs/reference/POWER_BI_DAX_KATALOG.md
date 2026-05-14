# Power BI DAX Measures Katalog

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → DAX Katalog
> **Zweck**: DAX Measures Library, Farbschema, Performance-Patterns

## Core KPI Measures

### kpi_a - Posteingang vergangener Arbeitstag
```dax
kpi_a_last_working_day =
VAR LastWorkingDay =
    CALCULATE(
        MAX('WorkingDays'[Date]),
        'WorkingDays'[WorkingDaysRelativeToToday] = -1
    )
RETURN
    CALCULATE(
        SUM('Dashboard'[kpi_a_last_working_day]),
        'Dashboard'[Datum] = LastWorkingDay
    )
```

### kpi_a Trend-Calculation
```dax
E1_Trend =
VAR AktuellerWert = [kpi_a_last_working_day]
VAR VorwochenWert =
    CALCULATE(
        [kpi_a_last_working_day],
        DATEADD('Dashboard'[Datum], -7, DAY)
    )
RETURN
IF(
    NOT(ISBLANK(VorwochenWert)) && VorwochenWert > 0,
    DIVIDE(AktuellerWert - VorwochenWert, VorwochenWert),
    BLANK()
)
```

### S3 Status-Indikator
```dax
S3_Status =
VAR Wert = [S3_Gesamt]
RETURN
SWITCH(
    TRUE(),
    Wert > 1000, "Kritisch",
    Wert > 500, "Warnung",
    "OK"
)
```

## Farbcodierung-Schema

### Status-Indikatoren
```css
.status-ok {
    background-color: #28a745;    /* Grün */
    color: white;
}

.status-warning {
    background-color: #ffc107;    /* Gelb/Orange */
    color: black;
}

.status-critical {
    background-color: #dc3545;   /* Rot */
    color: white;
}
```

### Conditional Formatting Logic
```dax
KPI_Status_Color =
VAR KPI_Value = [Current_KPI_Value]
VAR Critical_Threshold = [Critical_Threshold]
VAR Warning_Threshold = [Warning_Threshold]

RETURN
SWITCH(
    TRUE(),
    KPI_Value > Critical_Threshold, "#dc3545",  /* Rot */
    KPI_Value > Warning_Threshold, "#ffc107",   /* Gelb */
    "#28a745"                                   /* Grün */
)
```

## Performance-Optimierte Measures

### DirectQuery-optimierte Calculationen
```dax
-- Vermeidet komplexe Iterator-Funktionen
E1_Optimized =
CALCULATE(
    SELECTEDVALUE('Dashboard_Live'[kpi_a_last_working_day]),
    'Dashboard_Live'[ID] = 1
)
```

---
**Siehe auch**:
- [Power BI Dashboard-Entwicklung](../how-to/POWER_BI_DASHBOARD_ENTWICKLUNG.md) - Deployment
- [PostgreSQL Daily Ops](../how-to/POSTGRESQL_DAILY_OPS.md) - DirectQuery Optimization
