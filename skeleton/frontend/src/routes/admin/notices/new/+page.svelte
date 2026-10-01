<script lang="ts">
  import NoticeForm from "#lib/components/admin/NoticeForm.svelte"

  // 새 공지 — 처음 저장하면 NoticeForm 이 수정 화면(/admin/notices/[id]/edit)으로 옮겨 첨부 패널을 연다.
</script>

<svelte:head>
  <title>새 공지 · 관리자 콘솔</title>
</svelte:head>

<NoticeForm notice={null} />
