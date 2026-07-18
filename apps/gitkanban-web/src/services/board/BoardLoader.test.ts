import { describe, expect, it } from "vitest";

import { cardMatchesQuery, cardTitle } from "./BoardLoader";
import type { BoardCard, LoadedBoard } from "./BoardLoader.model";

const card: BoardCard = {
  frontmatter: {
    id: "GITKIT-123",
    title: "Build the web board",
    status: "todo",
    assignee: "sil",
  },
  body: "Markdown body content",
  path: "Tasks/GitKit/1. To do/build-web.md",
  fileName: "build-web.md",
};

const config = {
  fieldSource: { mode: "frontmatter" },
} satisfies Pick<LoadedBoard["config"], "fieldSource">;

describe("BoardLoader helpers", () => {
  it("uses card frontmatter for display titles", () => {
    expect(cardTitle(card, config)).toBe("Build the web board");
  });

  it("matches query text against modelled fields and body", () => {
    expect(cardMatchesQuery(card, "sil", config as LoadedBoard["config"])).toBe(true);
    expect(cardMatchesQuery(card, "markdown body", config as LoadedBoard["config"])).toBe(true);
    expect(cardMatchesQuery(card, "not-present", config as LoadedBoard["config"])).toBe(false);
  });
});

