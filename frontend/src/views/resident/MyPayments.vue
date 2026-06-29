<template>
  <div>
    <h2>💰 我的缴费</h2>
    <el-table :data="list" border stripe v-loading="loading" style="margin-top: 8px" max-height="calc(100vh - 230px)">
      <el-table-column prop="paymentId" label="ID" width="80" />
      <el-table-column prop="billId" label="账单ID" width="80" />
      <el-table-column prop="amount" label="金额(元)" width="100" />
      <el-table-column prop="channel" label="渠道" width="80">
        <template #default="{ row }">
          <el-tag :type="row.channel === 'ONLINE' ? 'success' : 'warning'" size="small">
            {{ row.channel === 'ONLINE' ? '线上' : '线下' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="paymentTime" label="缴费时间" width="160" />
      <el-table-column prop="transactionNo" label="流水号" min-width="200" show-overflow-tooltip />
    </el-table>

    <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import paymentApi from '@/api/payment'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)

onMounted(() => fetchList())

async function fetchList() {
  loading.value = true
  try {
    const res = await paymentApi.list({ page: currentPage.value, pageSize: 20 })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}
</script>
