import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { serializeCard, type CardFields, type Lane } from "@gitkit/gitkanban-core";

import {
  cardMatchesQuery,
  loadProjectBoard,
  loadWorkspace,
  type BoardCard,
  type BoardProject,
  type GitHubClient,
  GitHubClient as Client,
  type GitHubCommitInfo,
  type GitHubRepo,
  type LoadedBoard,
  type LoadedWorkspace,
  consumeGitHubOAuthCallback,
  startGitHubOAuth,
} from "@/services";

const tokenKey = "gitkanban-web-token";
const rootPathKey = "gitkanban-web-root-path";
const lastRepoKey = "gitkanban-web-last-repo";
const lastProjectKey = "gitkanban-web-last-project";

export const useGitKanbanStore = defineStore("gitkanban", () => {
  const token = ref(localStorage.getItem(tokenKey) ?? "");
  const login = ref("");
  const repos = ref<GitHubRepo[]>([]);
  const selectedRepo = ref<GitHubRepo | null>(null);
  const workspace = ref<LoadedWorkspace | null>(null);
  const selectedProject = ref<BoardProject | null>(null);
  const board = ref<LoadedBoard | null>(null);
  const selectedCardPath = ref<string | null>(null);
  const boardRootPath = ref(localStorage.getItem(rootPathKey) ?? "Tasks");
  const repoSearch = ref("");
  const boardSearch = ref("");
  const viewMode = ref<"lanes" | "list">("lanes");
  const filterAssignee = ref("");
  const filterPriority = ref("");
  const filterType = ref("");
  const isConnecting = ref(false);
  const isLoadingRepos = ref(false);
  const isLoadingBoard = ref(false);
  const isSaving = ref(false);
  const errorMessage = ref("");

  const client = computed<GitHubClient | null>(() => token.value ? new Client({ token: token.value }) : null);
  const isConnected = computed(() => Boolean(token.value && login.value));
  const selectedCard = computed(() => {
    const allCards = [
      ...(board.value?.columns.flatMap((column) => column.cards) ?? []),
      ...(board.value?.uncategorised ?? []),
    ];
    return allCards.find((card) => card.path === selectedCardPath.value) ?? null;
  });
  const filteredRepos = computed(() => {
    const query = repoSearch.value.trim().toLowerCase();
    if (!query) return repos.value;
    return repos.value.filter((repo) => repo.fullName.toLowerCase().includes(query));
  });
  const assignees = computed(() => {
    const configured = board.value?.config.users.map((user) => user.id) ?? [];
    const fromCards = allBoardCards().map((card) => String(card.frontmatter.assignee ?? "")).filter(Boolean);
    return [...new Set([...configured, ...fromCards])].sort();
  });
  const priorities = computed(() => board.value?.config.priorities ?? []);
  const types = computed(() => {
    const configured = board.value?.config.types ?? [];
    const fromCards = allBoardCards().map((card) => String(card.frontmatter.type ?? "")).filter(Boolean);
    return [...new Set([...configured, ...fromCards])].sort();
  });
  const hasActiveFilters = computed(() => Boolean(
    filterAssignee.value || filterPriority.value || filterType.value || boardSearch.value.trim(),
  ));

  async function connectWithToken(rawToken: string): Promise<void> {
    token.value = rawToken.trim();
    if (!token.value) {
      errorMessage.value = "Enter a GitHub token first.";
      return;
    }

    isConnecting.value = true;
    errorMessage.value = "";
    try {
      const activeClient = new Client({ token: token.value });
      const viewer = await activeClient.viewer();
      login.value = viewer.login;
      localStorage.setItem(tokenKey, token.value);
      await loadRepos();
    } catch (error) {
      signOut();
      errorMessage.value = errorMessageFrom(error);
    } finally {
      isConnecting.value = false;
    }
  }

  async function connectWithGitHub(): Promise<void> {
    await startGitHubOAuth();
  }

  async function completeOAuthIfPresent(): Promise<void> {
    const accessToken = await consumeGitHubOAuthCallback();
    if (accessToken) await connectWithToken(accessToken);
  }

  async function restore(): Promise<void> {
    await completeOAuthIfPresent();
    if (!token.value) return;
    isConnecting.value = true;
    try {
      const activeClient = new Client({ token: token.value });
      login.value = (await activeClient.viewer()).login;
      await loadRepos();
      const lastRepo = localStorage.getItem(lastRepoKey);
      const repo = repos.value.find((item) => item.fullName === lastRepo);
      if (repo) await openRepo(repo);
    } catch {
      signOut();
    } finally {
      isConnecting.value = false;
    }
  }

  async function loadRepos(): Promise<void> {
    if (!client.value) return;
    isLoadingRepos.value = true;
    errorMessage.value = "";
    try {
      repos.value = await client.value.listRepos();
    } catch (error) {
      errorMessage.value = errorMessageFrom(error);
    } finally {
      isLoadingRepos.value = false;
    }
  }

  async function openRepo(repo: GitHubRepo): Promise<void> {
    if (!client.value) return;
    selectedRepo.value = repo;
    selectedProject.value = null;
    board.value = null;
    selectedCardPath.value = null;
    isLoadingBoard.value = true;
    errorMessage.value = "";
    localStorage.setItem(rootPathKey, boardRootPath.value);
    localStorage.setItem(lastRepoKey, repo.fullName);

    try {
      workspace.value = await loadWorkspace(client.value, repo, boardRootPath.value);
      const lastProject = localStorage.getItem(lastProjectKey);
      const project = workspace.value.projects.find((item) => item.id === lastProject) ?? workspace.value.projects[0];
      if (project) await selectProject(project);
    } catch (error) {
      workspace.value = null;
      errorMessage.value = errorMessageFrom(error);
    } finally {
      isLoadingBoard.value = false;
    }
  }

  async function selectProject(project: BoardProject): Promise<void> {
    if (!client.value || !workspace.value) return;
    isLoadingBoard.value = true;
    selectedProject.value = project;
    selectedCardPath.value = null;
    clearFilters();
    localStorage.setItem(lastProjectKey, project.id);
    try {
      board.value = await loadProjectBoard(client.value, workspace.value, project);
    } catch (error) {
      errorMessage.value = errorMessageFrom(error);
    } finally {
      isLoadingBoard.value = false;
    }
  }

  async function cardHistory(path: string): Promise<GitHubCommitInfo[]> {
    if (!client.value || !selectedRepo.value) return [];
    return client.value.fileHistory(selectedRepo.value, path);
  }

  async function createTask(options: {
    title: string;
    lane: Lane;
    body?: string;
    priority?: string;
    type?: string;
    assignee?: string;
  }): Promise<void> {
    if (!client.value || !selectedRepo.value || !selectedProject.value) return;
    const title = options.title.trim();
    if (!title) {
      errorMessage.value = "A task needs a title.";
      return;
    }
    const fileName = `${slug(title)}.md`;
    const path = `${selectedProject.value.path}/${options.lane.folder}/${fileName}`;
    const id = fileName.replace(/\.md$/, "");
    const content = serializeCard({
      frontmatter: compactRecord({
        id,
        title,
        project: selectedProject.value.name,
        status: options.lane.status,
        priority: options.priority,
        type: options.type,
        assignee: options.assignee,
      }),
      body: `${options.body?.trim() ?? ""}\n`,
    });
    await commitAndReload(`Add task ${id}`, [{ path, content }]);
  }

  async function updateTask(card: BoardCard, fields: CardFields, body: string, lane: Lane): Promise<void> {
    if (!selectedProject.value) return;
    const updated = {
      frontmatter: {
        ...card.frontmatter,
        id: fields.id,
        title: fields.title,
        project: fields.project,
        status: lane.status,
        priority: fields.priority || undefined,
        type: fields.type || undefined,
        epic: fields.epic || undefined,
        assignee: fields.assignee || undefined,
        order: fields.order || undefined,
      },
      body: body.endsWith("\n") ? body : `${body}\n`,
    };
    const moved = lane.folder && !card.path.includes(`/${lane.folder}/`);
    const nextPath = moved ? `${selectedProject.value.path}/${lane.folder}/${card.fileName}` : card.path;
    const changes = moved
      ? [{ path: nextPath, content: serializeCard(updated) }, { path: card.path, content: null }]
      : [{ path: card.path, content: serializeCard(updated) }];
    await commitAndReload(`Update ${fields.id}`, changes);
  }

  async function moveTask(card: BoardCard, lane: Lane): Promise<void> {
    const fields = cardFields(card);
    await updateTask(card, { ...fields, status: lane.status }, card.body, lane);
  }

  async function deleteTask(card: BoardCard): Promise<void> {
    const fields = cardFields(card);
    await commitAndReload(`Delete ${fields.id || card.fileName}`, [{ path: card.path, content: null }]);
    selectedCardPath.value = null;
  }

  function filteredCards(cards: BoardCard[]): BoardCard[] {
    return cards.filter((card) => {
      if (!board.value) return true;
      const fields = card.frontmatter;
      if (filterAssignee.value && fields.assignee !== filterAssignee.value) return false;
      if (filterPriority.value && fields.priority !== filterPriority.value) return false;
      if (filterType.value && fields.type !== filterType.value) return false;
      return cardMatchesQuery(card, boardSearch.value, board.value.config);
    });
  }

  function clearFilters(): void {
    filterAssignee.value = "";
    filterPriority.value = "";
    filterType.value = "";
    boardSearch.value = "";
  }

  function signOut(): void {
    localStorage.removeItem(tokenKey);
    token.value = "";
    login.value = "";
    repos.value = [];
    selectedRepo.value = null;
    workspace.value = null;
    selectedProject.value = null;
    board.value = null;
    selectedCardPath.value = null;
  }

  function openNativeApp(): void {
    if (!selectedRepo.value) return;
    const params = new URLSearchParams({
      repo: selectedRepo.value.fullName,
      branch: selectedRepo.value.defaultBranch,
      root: boardRootPath.value,
    });
    if (selectedProject.value) params.set("project", selectedProject.value.folder);
    window.location.href = `gitkanban://open?${params.toString()}`;
  }

  async function commitAndReload(message: string, changes: Array<{ path: string; content: string | null }>): Promise<void> {
    if (!client.value || !selectedRepo.value || !selectedProject.value) return;
    isSaving.value = true;
    errorMessage.value = "";
    try {
      await client.value.commitFiles(selectedRepo.value, message, changes);
      const project = selectedProject.value;
      await openRepo(selectedRepo.value);
      const reselected = workspace.value?.projects.find((item) => item.id === project.id);
      if (reselected) await selectProject(reselected);
    } catch (error) {
      errorMessage.value = errorMessageFrom(error);
    } finally {
      isSaving.value = false;
    }
  }

  function allBoardCards(): BoardCard[] {
    return [
      ...(board.value?.columns.flatMap((column) => column.cards) ?? []),
      ...(board.value?.uncategorised ?? []),
    ];
  }

  return {
    token,
    login,
    repos,
    filteredRepos,
    selectedRepo,
    workspace,
    selectedProject,
    board,
    selectedCard,
    selectedCardPath,
    boardRootPath,
    repoSearch,
    boardSearch,
    viewMode,
    filterAssignee,
    filterPriority,
    filterType,
    assignees,
    priorities,
    types,
    hasActiveFilters,
    isConnected,
    isConnecting,
    isLoadingRepos,
    isLoadingBoard,
    isSaving,
    errorMessage,
    connectWithToken,
    connectWithGitHub,
    completeOAuthIfPresent,
    restore,
    loadRepos,
    openRepo,
    selectProject,
    cardHistory,
    createTask,
    updateTask,
    moveTask,
    deleteTask,
    filteredCards,
    clearFilters,
    signOut,
    openNativeApp,
  };
});

function errorMessageFrom(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function compactRecord(input: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(input).filter(([, value]) => value !== undefined && value !== ""));
}

function slug(input: string): string {
  const value = input.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return value || "task";
}

function cardFields(card: BoardCard): CardFields {
  const frontmatter = card.frontmatter;
  return {
    id: String(frontmatter.id ?? ""),
    title: String(frontmatter.title ?? ""),
    project: String(frontmatter.project ?? ""),
    status: String(frontmatter.status ?? ""),
    priority: String(frontmatter.priority ?? "") || null,
    type: String(frontmatter.type ?? "") || null,
    epic: String(frontmatter.epic ?? "") || null,
    assignee: String(frontmatter.assignee ?? "") || null,
    order: String(frontmatter.order ?? "") || null,
  };
}
