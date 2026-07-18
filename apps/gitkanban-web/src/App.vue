<template>
  <main :class="bemm()">
    <section v-if="!store.isConnected" :class="bemm('connect')">
      <div :class="bemm('connect-panel')">
        <div :class="bemm('mark')">GK</div>
        <div :class="bemm('connect-copy')">
          <h1 :class="bemm('title')">GitKanban</h1>
          <p :class="bemm('muted')">
            Open a GitHub-backed markdown board in the browser. The production OAuth broker is
            planned; this build uses a fine-grained token so the board path can be built for real.
          </p>
        </div>

        <button :class="bemm('primary')" type="button" :disabled="store.isConnecting" @click="store.connectWithGitHub">
          {{ store.isConnecting ? "Connecting..." : "Connect GitHub" }}
        </button>

        <details :class="bemm('advanced')">
          <summary :class="bemm('summary')">Use a token instead</summary>
          <form :class="bemm('token-form')" @submit.prevent="connect">
            <label :class="bemm('field')">
              <span :class="bemm('label')">GitHub token</span>
              <input
                v-model="tokenDraft"
                :class="bemm('input')"
                type="password"
                autocomplete="off"
                placeholder="github_pat_..."
              />
            </label>
            <button :class="bemm('secondary')" type="submit" :disabled="store.isConnecting">
              Connect with token
            </button>
          </form>
        </details>

        <p :class="bemm('hint')">
          GitHub OAuth uses PKCE in the browser. Tokens stay local to this browser session.
        </p>
      </div>
    </section>

    <section v-else :class="bemm('workspace')">
      <aside :class="bemm('sidebar')">
        <div :class="bemm('sidebar-header')">
          <div>
            <strong :class="bemm('sidebar-title')">GitKanban</strong>
            <span :class="bemm('account')">@{{ store.login }}</span>
          </div>
          <button :class="bemm('icon-button')" type="button" title="Sign out" @click="store.signOut">
            x
          </button>
        </div>

        <label :class="bemm('field')">
          <span :class="bemm('label')">Board root</span>
          <input v-model="store.boardRootPath" :class="bemm('input')" placeholder="Tasks" />
        </label>

        <label :class="bemm('field')">
          <span :class="bemm('label')">Repositories</span>
          <input v-model="store.repoSearch" :class="bemm('input')" placeholder="Filter repositories" />
        </label>

        <div :class="bemm('repo-list')">
          <button
            v-for="repo in store.filteredRepos"
            :key="repo.fullName"
            :class="bemm('repo', ['', repo.fullName === store.selectedRepo?.fullName ? 'active' : ''])"
            type="button"
            @click="store.openRepo(repo)"
          >
            <span :class="bemm('repo-name')">{{ repo.fullName }}</span>
            <span :class="bemm('repo-meta')">{{ repo.private ? "Private" : "Public" }}</span>
          </button>
        </div>
      </aside>

      <aside v-if="store.workspace" :class="bemm('projectbar')">
        <div :class="bemm('section-head')">
          <span>Projects</span>
          <span>{{ store.workspace.projects.length }}</span>
        </div>
        <button
          v-for="project in store.workspace.projects"
          :key="project.id"
          :class="bemm('project', ['', project.id === store.selectedProject?.id ? 'active' : ''])"
          type="button"
          @click="store.selectProject(project)"
        >
          <span :class="bemm('project-name')">{{ project.name }}</span>
          <span :class="bemm('project-meta')">
            {{ laneCount(project) }} lanes
          </span>
        </button>
      </aside>

      <section :class="bemm('board-shell')">
        <header :class="bemm('toolbar')">
          <div :class="bemm('toolbar-title')">
            <span :class="bemm('eyebrow')">{{ store.selectedRepo?.fullName ?? "No repository" }}</span>
            <h2 :class="bemm('board-title')">{{ store.selectedProject?.name ?? "Choose a project" }}</h2>
          </div>

          <div :class="bemm('toolbar-actions')">
            <button
              v-if="store.board?.config.lanes[0]"
              :class="bemm('primary')"
              type="button"
              :disabled="store.isSaving"
              @click="quickCreate(store.board.config.lanes[0])"
            >
              New Task
            </button>
            <button :class="bemm('secondary')" type="button" @click="store.openNativeApp">
              Open in GitKanban
            </button>
            <button :class="bemm('secondary')" type="button" @click="refreshBoard">
              Refresh
            </button>
          </div>
        </header>

        <div v-if="store.board" :class="bemm('filters')">
          <input
            v-model="store.boardSearch"
            :class="bemm('search')"
            placeholder="Search tasks by title, id, body, assignee..."
          />
          <select v-model="store.filterAssignee" :class="bemm('select')">
            <option value="">Anyone</option>
            <option v-for="assignee in store.assignees" :key="assignee" :value="assignee">
              @{{ assignee }}
            </option>
          </select>
          <select v-model="store.filterPriority" :class="bemm('select')">
            <option value="">Any priority</option>
            <option v-for="priority in store.priorities" :key="priority.id" :value="priority.id">
              {{ priority.name ?? priority.id }}
            </option>
          </select>
          <select v-model="store.filterType" :class="bemm('select')">
            <option value="">Any type</option>
            <option v-for="type in store.types" :key="type" :value="type">{{ type }}</option>
          </select>
          <button
            v-if="store.hasActiveFilters"
            :class="bemm('ghost')"
            type="button"
            @click="store.clearFilters"
          >
            Clear
          </button>
          <div :class="bemm('segments')">
            <button
              :class="bemm('segment', ['', store.viewMode === 'lanes' ? 'active' : ''])"
              type="button"
              @click="store.viewMode = 'lanes'"
            >
              Lanes
            </button>
            <button
              :class="bemm('segment', ['', store.viewMode === 'list' ? 'active' : ''])"
              type="button"
              @click="store.viewMode = 'list'"
            >
              List
            </button>
          </div>
        </div>

        <div v-if="store.isSaving" :class="bemm('saving')">Saving to GitHub...</div>
        <div v-if="store.errorMessage" :class="bemm('error')">{{ store.errorMessage }}</div>
        <div v-else-if="store.isLoadingBoard" :class="bemm('empty')">Loading board...</div>
        <div v-else-if="!store.workspace" :class="bemm('empty')">Choose a repository to open a board.</div>
        <div v-else-if="!store.board" :class="bemm('empty')">Choose a project from the sidebar.</div>
        <div v-else-if="store.viewMode === 'lanes'" :class="bemm('lanes')">
          <article
            v-for="column in displayColumns"
            :key="column.lane.id"
            :class="bemm('lane')"
          >
            <header :class="bemm('lane-head')">
              <span :class="bemm('lane-dot')" />
              <strong>{{ column.lane.name }}</strong>
              <span :class="bemm('count')">{{ column.cards.length }}</span>
            </header>
            <button
              v-if="column.lane.folder"
              :class="bemm('add-card')"
              type="button"
              :disabled="store.isSaving"
              @click="quickCreate(column.lane)"
              @dragover.prevent
              @drop="dropOnLane(column.lane)"
            >
              Add Task
            </button>
            <button
              v-for="card in column.cards"
              :key="card.path"
              :class="bemm('card')"
              type="button"
              draggable="true"
              @dragstart="draggingPath = card.path"
              @click="store.selectedCardPath = card.path"
            >
              <span :class="bemm('card-title')">{{ titleFor(card) }}</span>
              <span :class="bemm('card-meta')">
                <span v-if="fieldsFor(card).priority">{{ fieldsFor(card).priority }}</span>
                <span v-if="fieldsFor(card).assignee">@{{ fieldsFor(card).assignee }}</span>
              </span>
            </button>
          </article>
        </div>
        <div v-else :class="bemm('list')">
          <section v-for="column in displayColumns" :key="column.lane.id" :class="bemm('list-section')">
            <h3 :class="bemm('list-title')">{{ column.lane.name }} · {{ column.cards.length }}</h3>
            <button
              v-for="card in column.cards"
              :key="card.path"
              :class="bemm('row')"
              type="button"
              @click="store.selectedCardPath = card.path"
            >
              <span>{{ titleFor(card) }}</span>
              <span :class="bemm('row-meta')">{{ fieldsFor(card).id }}</span>
            </button>
          </section>
        </div>
      </section>

      <aside v-if="store.selectedCard" :class="bemm('detail')">
        <button :class="bemm('close')" type="button" @click="store.selectedCardPath = null">x</button>
        <span :class="bemm('eyebrow')">{{ fieldsFor(store.selectedCard).id }}</span>
        <input v-model="draftTitle" :class="bemm('detail-input')" />
        <div :class="bemm('detail-meta')">
          <select v-model="draftLaneID" :class="bemm('select')">
            <option v-for="lane in store.board?.config.lanes" :key="lane.id" :value="lane.id">
              {{ lane.name }}
            </option>
          </select>
          <select v-model="draftPriority" :class="bemm('select')">
            <option value="">No priority</option>
            <option v-for="priority in store.priorities" :key="priority.id" :value="priority.id">
              {{ priority.name ?? priority.id }}
            </option>
          </select>
          <input v-model="draftType" :class="bemm('input')" placeholder="Type" />
          <input v-model="draftAssignee" :class="bemm('input')" placeholder="Assignee" />
        </div>
        <textarea v-model="draftBody" :class="bemm('markdown')" />
        <div :class="bemm('detail-actions')">
          <button :class="bemm('primary')" type="button" :disabled="store.isSaving" @click="saveSelected">
            Save
          </button>
          <button :class="bemm('secondary')" type="button" :disabled="store.isSaving" @click="deleteSelected">
            Delete
          </button>
        </div>
        <a
          v-if="store.selectedRepo"
          :class="bemm('secondary')"
          :href="githubCardUrl(store.selectedCard.path)"
          target="_blank"
          rel="noreferrer"
        >
          Find on GitHub
        </a>
        <section :class="bemm('history')">
          <div :class="bemm('section-head')">
            <span>History</span>
            <button :class="bemm('ghost')" type="button" @click="loadHistory">Load</button>
          </div>
          <div v-if="historyLoading" :class="bemm('muted')">Loading history...</div>
          <a
            v-for="commit in history"
            :key="commit.id"
            :class="bemm('commit')"
            :href="commit.url"
            target="_blank"
            rel="noreferrer"
          >
            <span>{{ commit.message }}</span>
            <small>{{ commit.id.slice(0, 7) }} · {{ commit.author }}</small>
          </a>
        </section>
      </aside>
    </section>
  </main>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { resolveCardFields, type Column, type Lane } from "@gitkit/gitkanban-core";
import { useBemm } from "bemm";

import { cardTitle, type BoardCard } from "@/services";
import { useGitKanbanStore } from "./stores/useGitKanbanStore";

const bemm = useBemm("gitkanban-web", { includeBaseClass: true });
const store = useGitKanbanStore();
const tokenDraft = ref("");
const draggingPath = ref("");
const draftTitle = ref("");
const draftLaneID = ref("");
const draftPriority = ref("");
const draftType = ref("");
const draftAssignee = ref("");
const draftBody = ref("");
const history = ref<Array<{ id: string; message: string; author: string; date: string; url: string }>>([]);
const historyLoading = ref(false);

const displayColumns = computed(() => {
  if (!store.board) return [];
  const columns = store.board.columns.map((column) => ({
    lane: column.lane,
    cards: store.filteredCards(column.cards),
  }));
  const uncategorised = store.filteredCards(store.board.uncategorised);
  if (uncategorised.length > 0) {
    columns.push({
      lane: { id: "_uncategorised", name: "Uncategorised", folder: "", status: "" },
      cards: uncategorised,
    });
  }
  return columns as Array<Column & { cards: BoardCard[] }>;
});

onMounted(() => {
  store.restore();
});

watch(() => store.selectedCardPath, () => {
  history.value = [];
  seedDraft();
});

async function connect(): Promise<void> {
  await store.connectWithToken(tokenDraft.value);
  tokenDraft.value = "";
}

async function refreshBoard(): Promise<void> {
  if (store.selectedRepo) await store.openRepo(store.selectedRepo);
}

function titleFor(card: BoardCard): string {
  return cardTitle(card, store.board?.config);
}

function fieldsFor(card: BoardCard) {
  return resolveCardFields(card, store.board?.config.fieldSource);
}

function laneCount(project: { config: { lanes?: unknown[] } }): number {
  return project.config.lanes?.length || store.workspace?.rootConfig.lanes.length || 0;
}

function githubCardUrl(path: string): string {
  const repo = store.selectedRepo;
  if (!repo) return "#";
  return `${repo.htmlUrl}/blob/${repo.defaultBranch}/${path}`;
}

async function loadHistory(): Promise<void> {
  const card = store.selectedCard;
  if (!card) return;
  historyLoading.value = true;
  try {
    history.value = await store.cardHistory(card.path);
  } finally {
    historyLoading.value = false;
  }
}

function seedDraft(): void {
  const card = store.selectedCard;
  if (!card || !store.board) return;
  const fields = fieldsFor(card);
  draftTitle.value = fields.title;
  draftLaneID.value = store.board.config.lanes.find((lane) => lane.status === fields.status)?.id ?? "";
  draftPriority.value = fields.priority ?? "";
  draftType.value = fields.type ?? "";
  draftAssignee.value = fields.assignee ?? "";
  draftBody.value = card.body;
}

async function quickCreate(lane: Lane): Promise<void> {
  const title = window.prompt("Task title");
  if (!title) return;
  await store.createTask({ title, lane });
}

async function saveSelected(): Promise<void> {
  const card = store.selectedCard;
  const board = store.board;
  if (!card || !board) return;
  const current = fieldsFor(card);
  const lane = board.config.lanes.find((item) => item.id === draftLaneID.value) ?? board.config.lanes[0];
  if (!lane) return;
  await store.updateTask(card, {
    ...current,
    title: draftTitle.value.trim(),
    priority: draftPriority.value || null,
    type: draftType.value || null,
    assignee: draftAssignee.value || null,
  }, draftBody.value, lane);
}

async function deleteSelected(): Promise<void> {
  const card = store.selectedCard;
  if (!card || !window.confirm(`Delete ${titleFor(card)}?`)) return;
  await store.deleteTask(card);
}

async function dropOnLane(lane: Lane): Promise<void> {
  const card = [
    ...(store.board?.columns.flatMap((column) => column.cards) ?? []),
    ...(store.board?.uncategorised ?? []),
  ].find((item) => item.path === draggingPath.value);
  draggingPath.value = "";
  if (card) await store.moveTask(card, lane);
}
</script>
