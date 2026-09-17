{% macro team_name_short(team_name_column) -%}
    split({{ team_name_column }}, ' ')[offset(0)]
{%- endmacro %}
