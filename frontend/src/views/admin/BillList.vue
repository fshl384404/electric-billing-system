<template>
  <div>
    <h2>📄 账单查询</h2>
    <el-form :inline="true" style="margin: 8px 0">
      <el-form-item label="状态">
        <el-select v-model="filters.status" clearable placeholder="全部" @change="fetchList" style="width:110px">
          <el-option label="待缴费" value="PENDING" />
          <el-option label="已缴费" value="PAID" />
          <el-option label="已逾期" value="OVERDUE" />
        </el-select>
      </el-form-item>
      <el-form-item label="账期">
        <el-input v-model="filters.billMonth" placeholder="YYYYMM" clearable @change="fetchList" @clear="filters.billMonth=null;fetchList()" />
      </el-form-item>
    </el-form>

    <el-table :data="list" border stripe v-loading="loading" max-height="calc(100vh - 230px)">
      <el-table-column prop="billId" label="ID" width="70" />
      <el-table-column prop="meterId" label="电表ID" width="80" />
      <el-table-column prop="houseAddress" label="住宅地址" min-width="180" show-overflow-tooltip />
      <el-table-column prop="billMonth" label="账期" width="100" />
      <el-table-column prop="totalUsage" label="用电量(度)" width="110" />
      <el-table-column label="阶梯用量" width="180">
        <template #default="{ row }">
          {{ row.tier1Usage }} / {{ row.tier2Usage }} / {{ row.tier3Usage }}
        </template>
      </el-table-column>
      <el-table-column label="阶梯费用" width="180">
        <template #default="{ row }">
          {{ row.tier1Amount }} / {{ row.tier2Amount }} / {{ row.tier3Amount }}
        </template>
      </el-table-column>
      <el-table-column prop="totalAmount" label="电费(元)" width="100" />
      <el-table-column prop="lateFee" label="滞纳金" width="90" />
      <el-table-column prop="status" label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'PAID' ? 'success' : row.status === 'OVERDUE' ? 'danger' : 'warning'" size="small">
            {{ { PENDING: '待缴', PAID: '已缴', OVERDUE: '逾期' }[row.status] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="dueDate" label="截止日" width="100" />
      <el-table-column prop="paymentDate" label="缴费日" width="100" />
    </el-table>

    <el-pagination
      v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import billApi from '@/api/bill'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const filters = reactive({ status: null, billMonth: null })

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try {
    const res = await billApi.list({ page: currentPage.value, pageSize: pageSize.value, ...filters })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}
</script>
