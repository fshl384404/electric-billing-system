<template>
  <div>
    <h2>💰 缴费记录</h2>
    <el-form :inline="true" style="margin: 16px 0">
      <el-form-item label="账单ID">
        <el-input-number v-model="billId" :min="1" placeholder="输入账单ID查询" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" @click="fetchList">查询</el-button>
      </el-form-item>
    </el-form>

    <el-table :data="list" border stripe v-loading="loading">
      <el-table-column prop="paymentId" label="ID" width="80" />
      <el-table-column prop="billId" label="账单ID" width="80" />
      <el-table-column prop="amount" label="金额(元)" width="100" />
      <el-table-column prop="lateFeePaid" label="滞纳金" width="90" />
      <el-table-column prop="channel" label="渠道" width="90">
        <template #default="{ row }">
          <el-tag :type="row.channel === 'ONLINE' ? 'success' : 'warning'" size="small">
            {{ row.channel === 'ONLINE' ? '线上' : '线下' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="payerId" label="缴费人ID" width="90" />
      <el-table-column prop="collectorId" label="收款人ID" width="90" />
      <el-table-column prop="paymentTime" label="缴费时间" width="160" />
      <el-table-column prop="transactionNo" label="流水号" min-width="200" />
    </el-table>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import paymentApi from '@/api/payment'

const list = ref([])
const loading = ref(false)
const billId = ref(null)

async function fetchList() {
  if (!billId.value) return
  loading.value = true
  try { list.value = (await paymentApi.list(billId.value)).data.data } finally { loading.value = false }
}
</script>
