# wikidata_filter

EmergenceSystem filter that searches Wikidata and returns structured knowledge entities as embryos.

## API

Queries the [Wikidata API](https://www.wikidata.org/w/api.php) entity search endpoint. No API key required.

## Input

```json
{"query": "Albert Einstein"}
```

| Field     | Type    | Default | Description              |
|-----------|---------|---------|--------------------------|
| `query`   | string  | —       | Search term              |
| `value`   | string  | —       | Alias for `query`        |
| `timeout` | integer | `10`    | HTTP timeout in seconds  |

## Output

One embryo per matching entity:

```json
{
  "properties": {
    "url":    "https://www.wikidata.org/wiki/Q937",
    "resume": "German-born theoretical physicist",
    "title":  "Albert Einstein",
    "id":     "Q937",
    "source": "www.wikidata.org"
  }
}
```

## Capabilities

`wikidata`, `knowledge`, `structured`, `entities`

## Usage

```bash
rebar3 shell
```

## License

Apache-2.0
