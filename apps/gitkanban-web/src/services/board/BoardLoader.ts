import {
  groupIntoColumns,
  parseCard,
  parseFrontmatter,
  resolveEffectiveConfig,
  resolveCardFields,
  type BoardConfig,
  type Lane,
  type Priority,
  type ProjectConfig,
  type User,
} from "@gitkit/gitkanban-core";

import type { GitHubClient, GitHubRepo, GitHubTreeItem } from "@/services/github";
import type { BoardCard, BoardProject, LoadedBoard, LoadedWorkspace } from "./BoardLoader.model";

const readmeName = "README.md";

export async function loadWorkspace(
  client: GitHubClient,
  repo: GitHubRepo,
  rootPath: string,
): Promise<LoadedWorkspace> {
  const cleanRoot = normalizePath(rootPath);
  const tree = await client.readTree(repo);
  const rootReadme = pathJoin(cleanRoot, readmeName);
  const rootText = await client.readTextFile(repo, rootReadme);
  const rootConfig = normalizeBoardConfig(parseFrontmatter(rootText).data);
  const projectReadmes = tree
    .filter((item) => item.type === "blob")
    .filter((item) => isDirectProjectReadme(item, cleanRoot))
    .sort((a, b) => a.path.localeCompare(b.path));

  const projects = await Promise.all(
    projectReadmes.map(async (item) => {
      const text = await client.readTextFile(repo, item.path);
      return parseProjectReadme(item.path, cleanRoot, text);
    }),
  );

  return {
    repo,
    rootPath: cleanRoot,
    rootConfig,
    projects,
  };
}

export async function loadProjectBoard(
  client: GitHubClient,
  workspace: LoadedWorkspace,
  project: BoardProject,
): Promise<LoadedBoard> {
  const tree = await client.readTree(workspace.repo);
  const config = resolveEffectiveConfig(workspace.rootConfig, project.config);
  const cardItems = tree
    .filter((item) => item.type === "blob")
    .filter((item) => item.path.startsWith(`${project.path}/`))
    .filter((item) => item.path.endsWith(".md"))
    .filter((item) => item.path !== pathJoin(project.path, readmeName))
    .filter((item) => !item.path.endsWith("/README.md"));

  const cards = await Promise.all(
    cardItems.map(async (item) => {
      const text = await client.readTextFile(workspace.repo, item.path);
      const parsed = parseCard(text);
      const fileName = item.path.split("/").pop() ?? item.path;
      return {
        ...parsed,
        path: item.path,
        fileName,
      } satisfies BoardCard;
    }),
  );
  const grouped = groupIntoColumns(config, cards);

  return {
    repo: workspace.repo,
    rootPath: workspace.rootPath,
    rootConfig: workspace.rootConfig,
    project,
    config,
    columns: grouped.columns.map((column) => ({
      lane: column.lane,
      cards: column.cards as BoardCard[],
    })),
    uncategorised: grouped.uncategorised as BoardCard[],
  };
}

export function cardTitle(card: BoardCard, config?: { fieldSource?: LoadedBoard["config"]["fieldSource"] }): string {
  const fields = resolveCardFields(card, config?.fieldSource);
  return fields.title || fields.id || card.fileName;
}

export function cardMatchesQuery(card: BoardCard, query: string, config: LoadedBoard["config"]): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle) return true;
  const fields = resolveCardFields(card, config.fieldSource);
  return [fields.title, fields.id, fields.type ?? "", fields.assignee ?? "", card.body]
    .some((value) => value.toLowerCase().includes(needle));
}

function parseProjectReadme(path: string, rootPath: string, text: string): BoardProject {
  const document = parseFrontmatter(text);
  const config = normalizeProjectConfig(document.data);
  const folder = path.slice(rootPath.length ? rootPath.length + 1 : 0).replace(`/${readmeName}`, "");
  const name = config.project || folder.split("/").pop() || folder;
  return {
    id: folder,
    name,
    folder,
    path: path.replace(`/${readmeName}`, ""),
    config,
    description: firstParagraph(document.body),
  };
}

function normalizeBoardConfig(input: Record<string, unknown>): BoardConfig {
  return {
    ...input,
    lanes: normalizeLanes(input.lanes),
    users: normalizeUsers(input.users),
    epics: Array.isArray(input.epics) ? input.epics as BoardConfig["epics"] : [],
    priorities: normalizePriorities(input.priorities),
    types: normalizeStrings(input.types),
    tags: normalizeStrings(input.tags),
    fieldSource: input.fieldSource as BoardConfig["fieldSource"],
  };
}

function normalizeProjectConfig(input: Record<string, unknown>): ProjectConfig {
  return {
    ...input,
    project: typeof input.project === "string" ? input.project : undefined,
    lanes: Array.isArray(input.lanes) ? normalizeLanes(input.lanes) : undefined,
    users: Array.isArray(input.users) ? normalizeUsers(input.users) : undefined,
    epics: Array.isArray(input.epics) ? input.epics as ProjectConfig["epics"] : undefined,
    priorities: Array.isArray(input.priorities) ? normalizePriorities(input.priorities) : undefined,
    types: Array.isArray(input.types) ? normalizeStrings(input.types) : undefined,
    tags: Array.isArray(input.tags) ? normalizeStrings(input.tags) : undefined,
    fieldSource: input.fieldSource as ProjectConfig["fieldSource"],
  };
}

function normalizeLanes(input: unknown): Lane[] {
  if (!Array.isArray(input)) return defaultLanes();
  return input
    .filter((lane): lane is Record<string, unknown> => Boolean(lane) && typeof lane === "object")
    .map((lane) => ({
      id: String(lane.id ?? lane.status ?? lane.name ?? ""),
      name: String(lane.name ?? lane.id ?? lane.status ?? ""),
      folder: String(lane.folder ?? ""),
      status: String(lane.status ?? lane.id ?? ""),
      terminal: typeof lane.terminal === "boolean" ? lane.terminal : undefined,
    }))
    .filter((lane) => lane.id && lane.name && lane.status);
}

function normalizeUsers(input: unknown): User[] {
  if (!Array.isArray(input)) return [];
  return input
    .filter((user): user is Record<string, unknown> | string => typeof user === "string" || Boolean(user))
    .map((user) => typeof user === "string" ? { id: user } : { ...user, id: String(user.id ?? "") })
    .filter((user) => user.id);
}

function normalizePriorities(input: unknown): Priority[] {
  if (!Array.isArray(input)) return [];
  return input
    .filter((priority): priority is Record<string, unknown> | string => typeof priority === "string" || Boolean(priority))
    .map((priority) => typeof priority === "string" ? { id: priority } : { ...priority, id: String(priority.id ?? "") })
    .filter((priority) => priority.id);
}

function normalizeStrings(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  return input.map(String).filter(Boolean);
}

function defaultLanes(): Lane[] {
  return ["To do", "In Progress", "In Review", "Testing", "Done"].map((name, index) => {
    const status = name.toLowerCase().replace(/\s+/g, "-");
    return {
      id: status,
      name,
      folder: `${index + 1}. ${name}`,
      status,
      terminal: index === 4 ? true : undefined,
    };
  });
}

function isDirectProjectReadme(item: GitHubTreeItem, rootPath: string): boolean {
  const cleanRoot = normalizePath(rootPath);
  if (!item.path.endsWith(`/${readmeName}`)) return false;
  if (item.path === pathJoin(cleanRoot, readmeName)) return false;
  const relative = cleanRoot ? item.path.slice(cleanRoot.length + 1) : item.path;
  return relative.split("/").length === 2;
}

function normalizePath(path: string): string {
  return path.trim().replace(/^\/+|\/+$/g, "");
}

function pathJoin(...parts: string[]): string {
  return parts.filter(Boolean).join("/");
}

function firstParagraph(body: string): string {
  return body
    .split(/\n\s*\n/)
    .map((part) => part.replace(/^#+\s+/gm, "").trim())
    .find(Boolean) ?? "";
}

