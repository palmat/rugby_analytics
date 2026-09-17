{% macro int_surrogate_key(field_list) -%}
    {{ return(adapter.dispatch('int_surrogate_key', 'rugby_analytics')(field_list)) }}
{%- endmacro %}

{% macro default__int_surrogate_key(field_list) -%}
    {{ exceptions.raise_compiler_error(
        "int_surrogate_key: no implementation for adapter type '" ~ target.type ~ "'"
    ) }}
{%- endmacro %}

{% macro bigquery__int_surrogate_key(field_list) -%}
    farm_fingerprint(
        concat({% for field in field_list %}cast({{ field }} as string){% if not loop.last %}, '~', {% endif %}{% endfor %})
    )
{%- endmacro %}

{% macro redshift__int_surrogate_key(field_list) -%}
    strtol(
        substring(
            md5(concat({% for field in field_list %}cast({{ field }} as varchar){% if not loop.last %} || '~' || {% endif %}{% endfor %})),
            1, 15
        ),
        16
    )
{%- endmacro %}
