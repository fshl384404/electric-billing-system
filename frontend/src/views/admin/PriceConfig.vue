<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><Setting /></el-icon> 电价配置</h2>

    <!-- 民用电价 -->
    <el-card shadow="hover" style="margin-top:12px">
      <template #header><span style="font-weight:600">🏘️ 民用电价 (RESIDENTIAL)</span></template>
      <el-table :data="residentialList" border stripe>
        <el-table-column prop="tierNo" label="档位" width="60" />
        <el-table-column prop="tierName" label="名称" width="140" />
        <el-table-column label="用电量范围" width="180">
          <template #default="{ row }">{{ row.lowerLimit }} ~ {{ row.upperLimit || '无上限' }} kWh</template>
        </el-table-column>
        <el-table-column label="单价 (元/kWh)" width="180">
          <template #default="{ row }">
            <el-input-number
              v-if="editingId === row.configId"
              v-model="editForm.unitPrice" :precision="4" :step="0.01" :min="0" size="small"
            />
            <span v-else style="font-weight:600">{{ row.unitPrice }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <template v-if="editingId === row.configId">
              <el-button size="small" type="success" @click="savePrice(row)">保存</el-button>
              <el-button size="small" @click="editingId = null">取消</el-button>
            </template>
            <el-button v-else size="small" type="primary" @click="startEdit(row)">编辑</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 商用电价 -->
    <el-card shadow="hover" style="margin-top:16px">
      <template #header><span style="font-weight:600">🏢 商用电价 (COMMERCIAL)</span></template>
      <el-table :data="commercialList" border stripe>
        <el-table-column prop="tierNo" label="档位" width="60" />
        <el-table-column prop="tierName" label="名称" width="140" />
        <el-table-column label="用电量范围" width="180">
          <template #default="{ row }">{{ row.lowerLimit }} ~ {{ row.upperLimit || '无上限' }} kWh</template>
        </el-table-column>
        <el-table-column label="单价 (元/kWh)" width="180">
          <template #default="{ row }">
            <el-input-number
              v-if="editingId === row.configId"
              v-model="editForm.unitPrice" :precision="4" :step="0.01" :min="0" size="small"
            />
            <span v-else style="font-weight:600">{{ row.unitPrice }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <template v-if="editingId === row.configId">
              <el-button size="small" type="success" @click="savePrice(row)">保存</el-button>
              <el-button size="small" @click="editingId = null">取消</el-button>
            </template>
            <el-button v-else size="small" type="primary" @click="startEdit(row)">编辑</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import priceApi from '@/api/price'

const allList = ref([])
const editingId = ref(null)
const editForm = ref({})

const residentialList = computed(() => allList.value.filter(p => p.customerType === 'RESIDENTIAL'))
const commercialList = computed(() => allList.value.filter(p => p.customerType === 'COMMERCIAL'))

onMounted(() => fetchList())
async function fetchList() {
  try { allList.value = (await priceApi.list()).data.data } catch { /* ignore */ }
}

function startEdit(row) {
  editingId.value = row.configId
  editForm.value = { unitPrice: row.unitPrice }
}

async function savePrice(row) {
  await priceApi.update({ configId: row.configId, unitPrice: editForm.value.unitPrice })
  ElMessage.success('电价已更新')
  editingId.value = null
  fetchList()
}
</script>
