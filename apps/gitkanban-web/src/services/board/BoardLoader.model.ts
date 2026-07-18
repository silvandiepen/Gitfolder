import type {
  BoardConfig,
  Column,
  EffectiveConfig,
  ParsedCard,
  ProjectConfig,
} from "@gitkit/gitkanban-core";

import type { GitHubRepo } from "@/services/github";

export interface BoardProject {
  id: string;
  name: string;
  folder: string;
  path: string;
  config: ProjectConfig;
  description: string;
}

export interface BoardCard extends ParsedCard {
  path: string;
  fileName: string;
}

export interface LoadedBoard {
  repo: GitHubRepo;
  rootPath: string;
  rootConfig: BoardConfig;
  project: BoardProject;
  config: EffectiveConfig;
  columns: Array<Column & { cards: BoardCard[] }>;
  uncategorised: BoardCard[];
}

export interface LoadedWorkspace {
  repo: GitHubRepo;
  rootPath: string;
  rootConfig: BoardConfig;
  projects: BoardProject[];
}

