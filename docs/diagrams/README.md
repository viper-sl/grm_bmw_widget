# Architecture Diagrams

Rendered from the Mermaid blocks in [../ARCHITECTURE.md](../ARCHITECTURE.md). These `.svg`
images display in any markdown viewer / browser (no Mermaid plugin needed). The `.mmd`
sources are alongside each — edit those (or the blocks in `ARCHITECTURE.md`) and re-render:

```sh
cd docs/diagrams
for f in *.mmd; do npx -y @mermaid-js/mermaid-cli -i "$f" -o "${f%.mmd}.svg" -b transparent; done
```

---

## 1. Process & component map
![Process and component map](01-component-map.svg)

## 2. Two-container model
![Two-container model](02-two-container.svg)

## 3. Entry points & poll cadence
![Poll cadence](03-poll-cadence.svg)

## 4. Background poll (the fixed path)
![Background poll](04-background-poll.svg)

## 5. Foreground sync (full vs. live, manual vs. daily)
![Foreground sync](05-foreground-sync.svg)

## 6. Token lifecycle (FSM)
![Token FSM](06-token-fsm.svg)

## 7. Data flow: fetch → parse → cache → render
![Data flow](07-data-flow.svg)

## 8. Rate limit, quota & backoff
![Rate limit and quota](08-rate-limit.svg)

## 9. UI / navigation
![UI navigation](09-ui-navigation.svg)

## 10. Container resolution & versioning
![Container resolution](10-container-resolution.svg)
