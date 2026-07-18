import type {
  GitHubClientOptions,
  GitHubCommitInfo,
  GitHubFileChange,
  GitHubRepo,
  GitHubTreeItem,
  GitHubViewer,
} from "./GitHubClient.model";

interface GitHubRepoResponse {
  name: string;
  full_name: string;
  owner: { login: string };
  default_branch: string;
  private: boolean;
  html_url: string;
}

interface GitHubContentResponse {
  content?: string;
  encoding?: string;
}

interface GitHubTreeResponse {
  tree: GitHubTreeItem[];
  truncated: boolean;
}

interface GitHubCommitsResponse {
  sha: string;
  html_url: string;
  commit: {
    message: string;
    author?: {
      name?: string;
      date?: string;
    };
  };
  author?: {
    login?: string;
  } | null;
}

interface GitHubRefResponse {
  object: {
    sha: string;
  };
}

interface GitHubCommitResponse {
  sha: string;
  tree: {
    sha: string;
  };
}

interface GitHubBlobResponse {
  sha: string;
}

export class GitHubClient {
  private readonly token: string;
  private readonly baseUrl = "https://api.github.com";

  constructor(options: GitHubClientOptions) {
    this.token = options.token;
  }

  async viewer(): Promise<GitHubViewer> {
    return this.request<GitHubViewer>("/user");
  }

  async listRepos(): Promise<GitHubRepo[]> {
    const repos = await this.request<GitHubRepoResponse[]>(
      "/user/repos?per_page=100&sort=updated&affiliation=owner,collaborator,organization_member",
    );
    return repos.map(mapRepo);
  }

  async readTextFile(repo: GitHubRepo, path: string, ref = repo.defaultBranch): Promise<string> {
    const encodedPath = encodePath(path);
    const result = await this.request<GitHubContentResponse>(
      `/repos/${repo.fullName}/contents/${encodedPath}?ref=${encodeURIComponent(ref)}`,
    );
    if (result.encoding !== "base64" || !result.content) {
      throw new Error(`GitHub did not return base64 content for ${path}.`);
    }
    return decodeBase64(result.content);
  }

  async readTree(repo: GitHubRepo, ref = repo.defaultBranch): Promise<GitHubTreeItem[]> {
    const result = await this.request<GitHubTreeResponse>(
      `/repos/${repo.fullName}/git/trees/${encodeURIComponent(ref)}?recursive=1`,
    );
    if (result.truncated) {
      throw new Error("GitHub truncated the repository tree. Narrow the board path and try again.");
    }
    return result.tree;
  }

  async fileHistory(
    repo: GitHubRepo,
    path: string,
    ref = repo.defaultBranch,
    limit = 30,
  ): Promise<GitHubCommitInfo[]> {
    const commits = await this.request<GitHubCommitsResponse[]>(
      `/repos/${repo.fullName}/commits?sha=${encodeURIComponent(ref)}&path=${encodePath(path)}&per_page=${limit}`,
    );
    return commits.map((commit) => ({
      id: commit.sha,
      message: commit.commit.message,
      author: commit.author?.login ?? commit.commit.author?.name ?? "Unknown",
      date: commit.commit.author?.date ?? "",
      url: commit.html_url,
    }));
  }

  async commitFiles(
    repo: GitHubRepo,
    message: string,
    changes: GitHubFileChange[],
    ref = repo.defaultBranch,
  ): Promise<string> {
    const branch = ref.replace(/^refs\/heads\//, "");
    const currentRef = await this.request<GitHubRefResponse>(
      `/repos/${repo.fullName}/git/ref/heads/${encodeURIComponent(branch)}`,
    );
    const baseSha = currentRef.object.sha;
    const baseCommit = await this.request<GitHubCommitResponse>(
      `/repos/${repo.fullName}/git/commits/${baseSha}`,
    );

    const tree = [];
    for (const change of changes) {
      if (change.content === null) {
        tree.push({
          path: change.path,
          mode: "100644",
          type: "blob",
          sha: null,
        });
        continue;
      }
      const blob = await this.request<GitHubBlobResponse>(`/repos/${repo.fullName}/git/blobs`, {
        method: "POST",
        body: JSON.stringify({
          content: change.content,
          encoding: "utf-8",
        }),
      });
      tree.push({
        path: change.path,
        mode: "100644",
        type: "blob",
        sha: blob.sha,
      });
    }

    const nextTree = await this.request<GitHubBlobResponse>(`/repos/${repo.fullName}/git/trees`, {
      method: "POST",
      body: JSON.stringify({
        base_tree: baseCommit.tree.sha,
        tree,
      }),
    });
    const nextCommit = await this.request<GitHubCommitResponse>(`/repos/${repo.fullName}/git/commits`, {
      method: "POST",
      body: JSON.stringify({
        message,
        tree: nextTree.sha,
        parents: [baseSha],
      }),
    });
    await this.request<GitHubRefResponse>(`/repos/${repo.fullName}/git/refs/heads/${encodeURIComponent(branch)}`, {
      method: "PATCH",
      body: JSON.stringify({
        sha: nextCommit.sha,
        force: false,
      }),
    });
    return nextCommit.sha;
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2022-11-28",
        ...init.headers,
      },
    });

    if (!response.ok) {
      const message = await response.text();
      throw new Error(`GitHub ${response.status}: ${message || response.statusText}`);
    }

    return response.json() as Promise<T>;
  }
}

function mapRepo(repo: GitHubRepoResponse): GitHubRepo {
  return {
    name: repo.name,
    fullName: repo.full_name,
    ownerLogin: repo.owner.login,
    defaultBranch: repo.default_branch,
    private: repo.private,
    htmlUrl: repo.html_url,
  };
}

function encodePath(path: string): string {
  return path
    .split("/")
    .filter(Boolean)
    .map((part) => encodeURIComponent(part))
    .join("/");
}

function decodeBase64(input: string): string {
  const normalized = input.replace(/\s/g, "");
  const binary = atob(normalized);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}
