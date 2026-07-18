export interface GitHubRepo {
  name: string;
  fullName: string;
  ownerLogin: string;
  defaultBranch: string;
  private: boolean;
  htmlUrl: string;
}

export interface GitHubTreeItem {
  path: string;
  mode: string;
  type: "blob" | "tree" | "commit";
  sha: string;
  size?: number;
  url: string;
}

export interface GitHubCommitInfo {
  id: string;
  message: string;
  author: string;
  date: string;
  url: string;
}

export interface GitHubViewer {
  login: string;
}

export interface GitHubClientOptions {
  token: string;
}

export interface GitHubFileChange {
  path: string;
  content: string | null;
}
